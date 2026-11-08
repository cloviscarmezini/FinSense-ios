// Sources/FinSense/Services/BackendAPIClient.swift
import Foundation

public final class BackendAPIClient {
    public static let shared = BackendAPIClient()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func pushPull(
        baseURL: String,
        requestPayload: SyncPushPullRequest
    ) async throws -> SyncPushPullResponse {
        guard let url = URL(string: "\(baseURL)/sync/push-pull") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15.0

        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(requestPayload)

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpRes.statusCode == 200 else {
            throw URLError(httpRes.statusCode == 401 || httpRes.statusCode == 403 ? .userAuthenticationRequired : .badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(SyncPushPullResponse.self, from: data)
    }

    public func get<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15.0

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    public func post<Req: Encodable, Res: Decodable>(endpoint: String, body: Req) async throws -> Res {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 30.0

        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(Res.self, from: data)
    }
}
