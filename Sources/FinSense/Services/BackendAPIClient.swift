// Sources/FinSense/Services/BackendAPIClient.swift
import Foundation
import UIKit

public final class BackendAPIClient {
    public static let shared = BackendAPIClient()

    private let session: URLSession
    public var bearerToken: String? = nil
    public var tokenRenewer: (() async -> String?)? = nil

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public static var persistentDeviceId: String {
        let key = "finsense_persistent_device_id"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    public static func applyDeviceHeaders(to req: inout URLRequest) {
        req.setValue(persistentDeviceId, forHTTPHeaderField: "X-Device-Id")
        req.setValue("iOS", forHTTPHeaderField: "X-Platform")
        req.setValue("1.0.0", forHTTPHeaderField: "X-App-Version")
        let osVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        req.setValue("FinSense-iOS/1.0.0 (\(model); iOS \(osVersion))", forHTTPHeaderField: "User-Agent")
    }

    public func setBearerToken(_ token: String?) {
        self.bearerToken = token
    }

    public static func makeFlexibleDateDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let dateStr = try? container.decode(String.self) {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = isoFormatter.date(from: dateStr) { return d }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let d = isoFormatter.date(from: dateStr) { return d }

                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                for fmt in [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ] {
                    df.dateFormat = fmt
                    if let d = df.date(from: dateStr) { return d }
                }
            }
            if let num = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: num > 1e11 ? num / 1000.0 : num)
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
        return decoder
    }

    public func refreshTokens(
        baseURL: String,
        refreshToken: String
    ) async throws -> AuthResponseDTO {
        guard let url = URL(string: "\(baseURL)/auth/refresh") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        Self.applyDeviceHeaders(to: &req)
        req.timeoutInterval = 15.0

        let bodyPayload = RefreshTokenRequestDTO(
            refreshToken: refreshToken,
            deviceId: Self.persistentDeviceId,
            platform: "iOS",
            appVersion: "1.0.0",
            deviceName: UIDevice.current.name
        )
        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(bodyPayload)

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }

        let decoder = Self.makeFlexibleDateDecoder()
        return try decoder.decode(AuthResponseDTO.self, from: data)
    }

    public func pushPull(
        baseURL: String,
        requestPayload: SyncPushPullRequest,
        token: String? = nil
    ) async throws -> SyncPushPullResponse {
        guard let url = URL(string: "\(baseURL)/sync/push-pull") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        Self.applyDeviceHeaders(to: &req)

        if let authToken = token ?? bearerToken {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 25.0

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        req.httpBody = try encoder.encode(requestPayload)

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (httpRes.statusCode == 401 || httpRes.statusCode == 403), let renewer = tokenRenewer {
            if let newToken = await renewer() {
                var retryReq = req
                retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: retryReq)
                if let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 {
                    let decoder = Self.makeFlexibleDateDecoder()
                    return try decoder.decode(SyncPushPullResponse.self, from: retryData)
                }
            }
        }

        guard httpRes.statusCode == 200 else {
            throw URLError(httpRes.statusCode == 401 || httpRes.statusCode == 403 ? .userAuthenticationRequired : .badServerResponse)
        }

        let decoder = Self.makeFlexibleDateDecoder()
        return try decoder.decode(SyncPushPullResponse.self, from: data)
    }

    public func get<T: Decodable>(endpoint: String, token: String? = nil) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        Self.applyDeviceHeaders(to: &req)

        if let authToken = token ?? bearerToken {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 15.0

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (httpRes.statusCode == 401 || httpRes.statusCode == 403) && !endpoint.contains("/auth/"), let renewer = tokenRenewer {
            if let newToken = await renewer() {
                var retryReq = req
                retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: retryReq)
                if let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 {
                    let decoder = Self.makeFlexibleDateDecoder()
                    return try decoder.decode(T.self, from: retryData)
                }
            }
        }

        guard httpRes.statusCode == 200 else {
            throw URLError(httpRes.statusCode == 401 || httpRes.statusCode == 403 ? .userAuthenticationRequired : .badServerResponse)
        }

        let decoder = Self.makeFlexibleDateDecoder()
        return try decoder.decode(T.self, from: data)
    }

    public func post<Req: Encodable, Res: Decodable>(
        endpoint: String,
        body: Req,
        token: String? = nil
    ) async throws -> Res {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        Self.applyDeviceHeaders(to: &req)

        if let authToken = token ?? bearerToken {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 30.0

        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (httpRes.statusCode == 401 || httpRes.statusCode == 403) && !endpoint.contains("/auth/"), let renewer = tokenRenewer {
            if let newToken = await renewer() {
                var retryReq = req
                retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: retryReq)
                if let retryHttp = retryResponse as? HTTPURLResponse, (200...299).contains(retryHttp.statusCode) {
                    let decoder = Self.makeFlexibleDateDecoder()
                    return try decoder.decode(Res.self, from: retryData)
                }
            }
        }

        guard (200...299).contains(httpRes.statusCode) else {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorObj["message"] as? String {
                throw NSError(domain: "BackendAPI", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw URLError(httpRes.statusCode == 401 || httpRes.statusCode == 403 ? .userAuthenticationRequired : .badServerResponse)
        }

        let decoder = Self.makeFlexibleDateDecoder()
        return try decoder.decode(Res.self, from: data)
    }

    public func resetCloudData(
        baseURL: String,
        targets: [String]? = nil,
        token: String? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/sync/reset") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        Self.applyDeviceHeaders(to: &req)

        if let authToken = token ?? bearerToken {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        if let targets = targets, !targets.isEmpty {
            req.httpBody = try JSONSerialization.data(withJSONObject: ["targets": targets])
        }

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpRes.statusCode) else {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorObj["message"] as? String {
                throw NSError(domain: "BackendAPI", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw URLError(httpRes.statusCode == 401 || httpRes.statusCode == 403 ? .userAuthenticationRequired : .badServerResponse)
        }
    }
}
