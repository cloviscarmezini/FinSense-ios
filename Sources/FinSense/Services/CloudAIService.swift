// Sources/FinSense/Services/CloudAIService.swift
import Foundation
import UIKit

@MainActor
public final class CloudAIService: ObservableObject {
    @Published public var isInferringChat: Bool = false
    @Published public var isParsingReceipt: Bool = false
    @Published public var errorMessage: String? = nil

    private let apiClient: BackendAPIClient

    public init(apiClient: BackendAPIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Streaming SSE de Chat com a IA (Usando modelo default da API)
    public func streamChatMessage(
        messages: [ChatMessage],
        baseURL: String,
        bearerToken: String? = nil,
        onTokenReceived: @escaping (String) -> Void
    ) async throws -> String {
        isInferringChat = true
        errorMessage = nil
        defer { isInferringChat = false }

        guard let url = URL(string: "\(baseURL)/ai/chat/completions") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token = bearerToken ?? apiClient.bearerToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Sem parâmetro de modelo: a API utiliza o modelo padrão configurado no servidor
        let payload: [String: Any] = [
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "temperature": 0.2,
            "stream": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpRes.statusCode == 200 else {
            if httpRes.statusCode == 401 || httpRes.statusCode == 403 {
                throw URLError(.userAuthenticationRequired)
            }
            throw URLError(.badServerResponse)
        }

        var fullContent = ""
        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let dataPayload = String(line.dropFirst(6))
                if dataPayload == "[DONE]" { break }

                if let jsonData = dataPayload.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let chunk = delta["content"] as? String {
                    fullContent += chunk
                    onTokenReceived(chunk)
                }
            } else if !line.isEmpty {
                // Caso a API retorne JSON completo em vez de SSE
                if let jsonData = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    fullContent = content
                    onTokenReceived(content)
                    break
                }
            }
        }
        return fullContent
    }

    // MARK: - OCR Multimodal de Comprovantes com a Câmera
    public func parseReceiptImage(
        image: UIImage,
        baseURL: String,
        bearerToken: String? = nil
    ) async throws -> [ParsedTransactionDTO] {
        isParsingReceipt = true
        errorMessage = nil
        defer { isParsingReceipt = false }

        guard let url = URL(string: "\(baseURL)/ai/parse-statement") else {
            throw URLError(.badURL)
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.cannotDecodeContentData)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = bearerToken ?? apiClient.bearerToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpRes.statusCode == 200 else {
            if httpRes.statusCode == 401 || httpRes.statusCode == 403 {
                throw URLError(.userAuthenticationRequired)
            }
            throw URLError(.badServerResponse)
        }

        let parsed = try JSONDecoder().decode(AIStatementParseResponse.self, from: data)
        return parsed.transactions
    }
}
