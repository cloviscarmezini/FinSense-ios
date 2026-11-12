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
    private let backupTokenKey = "finsense_auth_access_token_backup"
    private let backupRefreshTokenKey = "finsense_auth_refresh_token_backup"
    private let sessionActiveKey = "finsense_auth_session_is_active"

    private var autoRenewalCancellable: AnyCancellable?
    private var ongoingRenewalTask: Task<Bool, Never>?

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
        let token = userDefaults.string(forKey: tokenKey) ?? userDefaults.string(forKey: backupTokenKey)
        let refresh = userDefaults.string(forKey: refreshTokenKey) ?? userDefaults.string(forKey: backupRefreshTokenKey)
        let isMarkedActive = userDefaults.bool(forKey: sessionActiveKey)

        let hasValidCredentials = (token != nil && !token!.isEmpty) || (refresh != nil && !refresh!.isEmpty) || isMarkedActive

        if hasValidCredentials {
            self.accessToken = token
            self.refreshToken = refresh
            if let userData = userDefaults.data(forKey: userKey),
               let user = try? JSONDecoder().decode(UserSummaryDTO.self, from: userData) {
                self.currentUser = user
            }
            self.isAuthenticated = true
            if let token {
                BackendAPIClient.shared.setBearerToken(token)
            }

            let isRunningUnderTests = NSClassFromString("XCTestCase") != nil
            if !isRunningUnderTests {
                startAutoRenewalLoop()
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
            autoRenewalCancellable?.cancel()
        }
    }

    public func renewTokens(baseURL: String? = nil) async -> Bool {
        if let task = ongoingRenewalTask {
            return await task.value
        }

        let refreshCandidate = refreshToken ?? userDefaults.string(forKey: backupRefreshTokenKey)
        guard let refresh = refreshCandidate, !refresh.isEmpty else {
            print("🚨 [FinSense-iOS] Sem refresh token disponível para renovação.")
            return false
        }

        let targetBaseURL = baseURL ?? currentBaseURL
        let task = Task<Bool, Never> { @MainActor in
            defer { self.ongoingRenewalTask = nil }

            do {
                let res = try await BackendAPIClient.shared.refreshTokens(
                    baseURL: targetBaseURL,
                    refreshToken: refresh
                )
                self.saveAuthResponse(res)
                print("⚡️ [FinSense-iOS] Token de acesso renovado automaticamente via /auth/refresh.")
                return true
            } catch let apiError as NSError where apiError.domain == "FinSenseAPI" && (apiError.code == 401 || apiError.code == 403) {
                print("🚨 [FinSense-iOS] Servidor rejeitou refresh token (\(apiError.code)). Sessão encerrada.")
                await self.logout(baseURL: targetBaseURL)
                return false
            } catch let urlErr as URLError where urlErr.code == .userAuthenticationRequired {
                print("🚨 [FinSense-iOS] Endpoint de refresh retornou 401. Sessão encerrada.")
                await self.logout(baseURL: targetBaseURL)
                return false
            } catch {
                print("⚠️ [FinSense-iOS] Falha de conexão ao renovar token (\(error.localizedDescription)). Mantendo autenticação perene.")
                return false
            }
        }

        self.ongoingRenewalTask = task
        return await task.value
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
        autoRenewalCancellable?.cancel()
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
        userDefaults.removeObject(forKey: backupTokenKey)
        userDefaults.removeObject(forKey: backupRefreshTokenKey)
        userDefaults.removeObject(forKey: sessionActiveKey)
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
        userDefaults.set(res.accessToken, forKey: backupTokenKey)
        userDefaults.set(res.refreshToken, forKey: backupRefreshTokenKey)
        userDefaults.set(true, forKey: sessionActiveKey)

        if let userData = try? JSONEncoder().encode(res.user) {
            userDefaults.set(userData, forKey: userKey)
        }

        BackendAPIClient.shared.setBearerToken(res.accessToken)
        startAutoRenewalLoop()
    }

    private func startAutoRenewalLoop() {
        autoRenewalCancellable?.cancel()
        guard NSClassFromString("XCTestCase") == nil else { return }
        // Proactively renew tokens every 15 minutes (900 seconds) while authenticated
        autoRenewalCancellable = Timer.publish(every: 900, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isAuthenticated else { return }
                Task {
                    _ = await self.renewTokens()
                }
            }
    }
}
