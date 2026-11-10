// Sources/FinSense/Services/AuthService.swift
import Foundation
import Combine
import UIKit

@MainActor
public final class AuthService: ObservableObject {
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: UserSummaryDTO? = nil
    @Published public var accessToken: String? = nil
    @Published public var refreshToken: String? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    private let userDefaults = UserDefaults.standard
    private let tokenKey = "finsense_auth_access_token"
    private let refreshTokenKey = "finsense_auth_refresh_token"
    private let userKey = "finsense_auth_user_summary"

    public var currentBaseURL: String {
        userDefaults.string(forKey: "cloud_sync_base_url") ?? AppConfiguration.shared.apiBaseURL
    }

    public init() {
        restoreSession()
        BackendAPIClient.shared.tokenRenewer = { [weak self] in
            await self?.ensureFreshToken()
        }
    }

    public static func jwtExpirationDate(from token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    public var isAccessTokenExpiringSoon: Bool {
        guard let token = accessToken else { return true }
        guard let expDate = Self.jwtExpirationDate(from: token) else { return false }
        // Se expira nos próximos 120 segundos ou já expirou
        return expDate.timeIntervalSinceNow < 120.0
    }

    public func restoreSession() {
        if let token = userDefaults.string(forKey: tokenKey), !token.isEmpty {
            self.accessToken = token
            self.refreshToken = userDefaults.string(forKey: refreshTokenKey)
            if let userData = userDefaults.data(forKey: userKey),
               let user = try? JSONDecoder().decode(UserSummaryDTO.self, from: userData) {
                self.currentUser = user
            }
            self.isAuthenticated = true
            BackendAPIClient.shared.setBearerToken(token)

            // Renovação preventiva imediata se o token expirou enquanto o app esteve em background
            if isAccessTokenExpiringSoon && refreshToken != nil {
                Task { [weak self] in
                    _ = await self?.renewTokens()
                }
            }
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
            self.accessToken = nil
            self.refreshToken = nil
            BackendAPIClient.shared.setBearerToken(nil)
        }
    }

    public func renewTokens(baseURL: String? = nil) async -> Bool {
        guard let refresh = refreshToken, !refresh.isEmpty else {
            return false
        }

        let targetBaseURL = baseURL ?? currentBaseURL
        do {
            let res = try await BackendAPIClient.shared.refreshTokens(
                baseURL: targetBaseURL,
                refreshToken: refresh
            )
            saveAuthResponse(res)
            print("⚡️ [FinSense-iOS] Token de acesso renovado automaticamente via /auth/refresh.")
            return true
        } catch {
            print("⚠️ [FinSense-iOS] Falha ao renovar token com o backend: \(error)")
            if let urlErr = error as? URLError, urlErr.code == .userAuthenticationRequired {
                // Refresh token também expirou após 30 dias de inatividade
                await logout(baseURL: targetBaseURL)
            }
            return false
        }
    }

    public func ensureFreshToken(baseURL: String? = nil) async -> String? {
        if isAccessTokenExpiringSoon {
            _ = await renewTokens(baseURL: baseURL)
        }
        return accessToken
    }

    public func login(email: String, password: String, baseURL: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let req = LoginRequestDTO(
            email: email.trimmingCharacters(in: .whitespaces),
            password: password,
            deviceId: BackendAPIClient.persistentDeviceId,
            platform: "iOS",
            appVersion: "1.0.0",
            deviceName: UIDevice.current.name
        )

        do {
            let res: AuthResponseDTO = try await BackendAPIClient.shared.post(
                endpoint: "\(baseURL)/auth/login",
                body: req
            )

            saveAuthResponse(res)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }

    public func register(fullName: String, email: String, password: String, baseURL: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let req = RegisterRequestDTO(
            email: email.trimmingCharacters(in: .whitespaces),
            password: password,
            fullName: fullName.trimmingCharacters(in: .whitespaces)
        )

        do {
            let res: AuthResponseDTO = try await BackendAPIClient.shared.post(
                endpoint: "\(baseURL)/auth/register",
                body: req
            )

            saveAuthResponse(res)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }

    public func logout(baseURL: String? = nil) async {
        let targetURL = baseURL ?? currentBaseURL
        if let token = accessToken {
            // Notifica o backend (logout) silenciosamente
            struct EmptyBody: Encodable {}
            let _: [String: AnyCodableValue]? = try? await BackendAPIClient.shared.post(
                endpoint: "\(targetURL)/auth/logout",
                body: EmptyBody(),
                token: token
            )
        }

        userDefaults.removeObject(forKey: tokenKey)
        userDefaults.removeObject(forKey: refreshTokenKey)
        userDefaults.removeObject(forKey: userKey)

        self.accessToken = nil
        self.refreshToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
        self.errorMessage = nil
        BackendAPIClient.shared.setBearerToken(nil)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func saveAuthResponse(_ res: AuthResponseDTO) {
        self.accessToken = res.accessToken
        self.refreshToken = res.refreshToken
        self.currentUser = res.user
        self.isAuthenticated = true
        self.errorMessage = nil

        userDefaults.set(res.accessToken, forKey: tokenKey)
        userDefaults.set(res.refreshToken, forKey: refreshTokenKey)
        if let userData = try? JSONEncoder().encode(res.user) {
            userDefaults.set(userData, forKey: userKey)
        }

        BackendAPIClient.shared.setBearerToken(res.accessToken)
    }
}
