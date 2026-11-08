// Sources/FinSense/Services/CloudAIService.swift
import Foundation
import UIKit

@MainActor
public final class CloudAIService: ObservableObject {
    @Published public var availableModels: [BackendAIModelInfo] = []
    @Published public var suggestedModels: [SuggestedBackendModel] = []
    @Published public var activeModelId: String? = nil
    @Published public var isDownloadingModel: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var activeDownloadTask: AIDownloadTaskStatusResponse? = nil
    @Published public var isInferringChat: Bool = false
    @Published public var isParsingReceipt: Bool = false
    @Published public var errorMessage: String? = nil

    private let apiClient: BackendAPIClient
    private var downloadPollingTask: Task<Void, Never>? = nil

    public init(apiClient: BackendAPIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 1. Listar Modelos do Backend
    public func fetchModelsCatalog(baseURL: String) async {
        do {
            let res: AIModelsCatalogResponse = try await apiClient.get(endpoint: "\(baseURL)/ai/models")
            self.availableModels = res.installedModels
            self.suggestedModels = res.suggestedModels
            self.activeModelId = res.selectedModelId
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Falha ao consultar modelos na nuvem: \(error.localizedDescription)"
        }
    }

    // MARK: - 2. Iniciar Download de Modelo do Hugging Face no Servidor
    public func startModelDownload(repoId: String, hfToken: String, baseURL: String) async {
        isDownloadingModel = true
        downloadProgress = 0.0

        struct DownloadReq: Codable {
            let repoId: String
            let huggingFaceToken: String
            enum CodingKeys: String, CodingKey {
                case repoId = "repo_id"
                case huggingFaceToken = "hugging_face_token"
            }
        }

        struct DownloadRes: Codable {
            let taskId: UUID
            enum CodingKeys: String, CodingKey { case taskId = "task_id" }
        }

        do {
            let res: DownloadRes = try await apiClient.post(
                endpoint: "\(baseURL)/ai/models/download",
                body: DownloadReq(repoId: repoId, huggingFaceToken: hfToken)
            )
            pollDownloadProgress(taskId: res.taskId, baseURL: baseURL)
        } catch {
            isDownloadingModel = false
            errorMessage = "Erro ao solicitar download: \(error.localizedDescription)"
        }
    }

    private func pollDownloadProgress(taskId: UUID, baseURL: String) {
        downloadPollingTask?.cancel()
        downloadPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
                guard let status: AIDownloadTaskStatusResponse = try? await apiClient.get(
                    endpoint: "\(baseURL)/ai/models/download/\(taskId.uuidString)"
                ) else { continue }

                self.activeDownloadTask = status
                self.downloadProgress = status.progressPercentage

                if status.status == "READY" {
                    self.isDownloadingModel = false
                    await fetchModelsCatalog(baseURL: baseURL)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    break
                } else if status.status == "FAILED" || status.status == "CANCELED" {
                    self.isDownloadingModel = false
                    self.errorMessage = status.errorMessage ?? "Download interrompido."
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    break
                }
            }
        }
    }

    // MARK: - 3. Selecionar Modelo Ativo na Nuvem
    public func selectActiveModel(modelId: String, baseURL: String) async -> Bool {
        struct SelectReq: Codable {
            let modelId: String
            enum CodingKeys: String, CodingKey { case modelId = "model_id" }
        }

        do {
            let _: [String: AnyCodableValue] = try await apiClient.post(
                endpoint: "\(baseURL)/ai/models/select",
                body: SelectReq(modelId: modelId)
            )
            self.activeModelId = modelId
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            self.errorMessage = "Falha ao ativar modelo: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 4. Streaming SSE de Chat com a IA
    public func streamChatMessage(
        messages: [ChatMessage],
        baseURL: String,
        onTokenReceived: @escaping (String) -> Void
    ) async throws -> String {
        isInferringChat = true
        defer { isInferringChat = false }

        guard let url = URL(string: "\(baseURL)/ai/chat/completions") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "temperature": 0.2,
            "stream": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: req)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
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
            }
        }
        return fullContent
    }

    // MARK: - 5. OCR Multimodal de Comprovantes com a Câmera
    public func parseReceiptImage(image: UIImage, baseURL: String) async throws -> [ParsedTransactionDTO] {
        isParsingReceipt = true
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

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let parsed = try JSONDecoder().decode(AIStatementParseResponse.self, from: data)
        return parsed.transactions
    }
}
