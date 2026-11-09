// Sources/FinSense/Services/AppConfiguration.swift
import Foundation

public struct AppConfiguration {
    public static let shared = AppConfiguration()

    public let apiBaseURL: String
    public let appEnvironment: String
    public let isVerboseLoggingEnabled: Bool

    public init() {
        let env = ProcessInfo.processInfo.environment

        #if DEBUG
        let fallbackBaseURL = "http://192.168.68.68:8080/api/v1"
        let fallbackEnv = "development"
        let fallbackVerbose = true
        #else
        let fallbackBaseURL = "https://api.finsense.com.br/v1"
        let fallbackEnv = "production"
        let fallbackVerbose = false
        #endif

        if let customBaseURL = env["API_BASE_URL"], !customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.apiBaseURL = customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.apiBaseURL = fallbackBaseURL
        }

        self.appEnvironment = env["APP_ENVIRONMENT"] ?? fallbackEnv
        self.isVerboseLoggingEnabled = (env["ENABLE_VERBOSE_LOGGING"] == "true") || fallbackVerbose
    }
}
