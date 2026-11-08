// Sources/FinSense/Views/AIChat/ModelSelectorSheet.swift
import SwiftUI

public struct ModelSelectorSheet: View {
    @ObservedObject var aiService: CloudAIService
    public var baseURL: String
    @Environment(\.dismiss) var dismiss

    @State private var hfRepoId: String = ""
    @State private var hfToken: String = ""
    @State private var isDownloadingAlert: Bool = false

    public init(aiService: CloudAIService, baseURL: String) {
        self.aiService = aiService
        self.baseURL = baseURL
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Modelo Ativo no Backend") {
                    if let activeId = aiService.activeModelId,
                       let active = aiService.availableModels.first(where: { $0.id == activeId }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(active.displayName)
                                    .font(.system(size: 14, weight: .bold))
                                Text(active.fileName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "#10B981"))
                        }
                    } else {
                        Text("Nenhum modelo selecionado")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                    }
                }

                Section("Modelos Instalados no Servidor (\(aiService.availableModels.count))") {
                    if aiService.availableModels.isEmpty {
                        Text("Nenhum modelo baixado no servidor ainda.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                    } else {
                        ForEach(aiService.availableModels) { model in
                            Button {
                                Task {
                                    let success = await aiService.selectActiveModel(modelId: model.id, baseURL: baseURL)
                                    if success {
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                        Text("\(model.quantization) • \(formatBytes(model.sizeBytes))")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    if model.id == aiService.activeModelId {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color(hex: "#0284C7"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Download do Hugging Face para o Servidor") {
                    TextField("Repo ID (ex: Qwen/Qwen2.5-3B-Instruct-GGUF)", text: $hfRepoId)
                        .autocapitalization(.none)

                    SecureField("Token Hugging Face (opcional para modelos públicos)", text: $hfToken)

                    if aiService.isDownloadingModel {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Baixando no backend...")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(String(format: "%.1f%%", aiService.downloadProgress))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            ProgressView(value: aiService.downloadProgress, total: 100.0)
                        }
                    } else {
                        Button {
                            guard !hfRepoId.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            Task {
                                await aiService.startModelDownload(repoId: hfRepoId, hfToken: hfToken, baseURL: baseURL)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Iniciar Download no Servidor")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(hex: "#0284C7"))
                    }
                }

                if !aiService.suggestedModels.isEmpty {
                    Section("Modelos Recomendados para Finanças") {
                        ForEach(aiService.suggestedModels) { suggested in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggested.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(suggested.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                    Text("Tamanho: ~\(suggested.sizeEstimate)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(hex: "#0284C7"))
                                }

                                Spacer()

                                if !suggested.isDownloaded {
                                    Button("Baixar") {
                                        hfRepoId = suggested.id
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .buttonStyle(.bordered)
                                } else {
                                    Text("Instalado")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: "#10B981"))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Modelos de IA na Nuvem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .task {
                await aiService.fetchModelsCatalog(baseURL: baseURL)
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
