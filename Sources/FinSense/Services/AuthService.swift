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

    public init() {
        restoreSession()
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
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
            self.accessToken = nil
            self.refreshToken = nil
            BackendAPIClient.shared.setBearerToken(nil)
        }
    }

    public func login(email: String, password: String, baseURL: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let req = LoginRequestDTO(email: email.trimmingCharacters(in: .whitespaces), password: password)

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

    public func logout(baseURL: String) async {
        if let token = accessToken {
            // Notifica o backend (logout) silenciosamente
            struct EmptyBody: Encodable {}
            let _: [String: AnyCodableValue]? = try? await BackendAPIClient.shared.post(
                endpoint: "\(baseURL)/auth/logout",
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
