// Sources/FinSense/Views/Settings/CloudSyncSettingsView.swift
import SwiftUI

public struct CloudSyncSettingsView: View {
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var store: FinancialDataStore

    @State private var isConfirmingFullUpload: Bool = false

    public init(syncService: CloudSyncService, store: FinancialDataStore) {
        self.syncService = syncService
        self.store = store
    }

    public var body: some View {
        Form {
            Section("Status da Sincronização") {
                Toggle("Habilitar Sincronização em Nuvem", isOn: $syncService.isEnabled)

                HStack {
                    Text("Estado Atual")
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: syncService.syncStatus.iconSymbol)
                            .foregroundStyle(statusColor)
                        Text(statusDescription)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                }

                if let last = syncService.lastSyncDate {
                    HStack {
                        Text("Última Sincronização")
                        Spacer()
                        Text(AppFormatters.shortDate(last))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                    }
                }

                HStack {
                    Text("Mutações Pendentes na Fila")
                    Spacer()
                    Text("\(syncService.pendingMutationsCount)")
                        .bold()
                }

                HStack {
                    Text("Revisão Monotônica do Servidor")
                    Spacer()
                    Text("\(syncService.lastServerRevision)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }
            }

            Section("Endereço da API do Backend") {
                TextField("URL Base", text: $syncService.baseURLString)
                    .autocapitalization(.none)
                    .keyboardType(.URL)

                Button("Predefinir: Servidor Mac Local (192.168.68.68:8080)") {
                    syncService.baseURLString = "http://192.168.68.68:8080/api/v1"
                }
                .font(.system(size: 12))

                Button("Predefinir: Localhost (Simulador 8080)") {
                    syncService.baseURLString = "http://localhost:8080/api/v1"
                }
                .font(.system(size: 12))

                Button("Predefinir: Produção") {
                    syncService.baseURLString = "https://api.finsense.com.br/v1"
                }
                .font(.system(size: 12))
            }

            Section("Ações de Sincronização") {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    syncService.performSync()
                } label: {
                    HStack {
                        Spacer()
                        if syncService.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Sincronizar Agora")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(!syncService.isEnabled || syncService.isSyncing)

                Button {
                    isConfirmingFullUpload = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Enviar Base Local Completa para a Nuvem")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#0284C7"))
                        Spacer()
                    }
                }
                .disabled(!syncService.isEnabled)
            }

            Section("Identificador do Cliente (Device)") {
                Text(syncService.clientId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.secondary)
            }
        }
        .navigationTitle("Sincronização em Nuvem")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Upload da Base Completa", isPresented: $isConfirmingFullUpload) {
            Button("Cancelar", role: .cancel) {}
            Button("Confirmar Envio") {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                syncService.queueEntireDatabaseForUpload(store: store)
                syncService.performSync()
            }
        } message: {
            Text("Todas as contas, transações, investimentos, dívidas e contratos locais serão enfileirados na outbox e enviados ao servidor.")
        }
    }

    private var statusDescription: String {
        switch syncService.syncStatus {
        case .synced: return "Sincronizado"
        case .syncing: return "Sincronizando..."
        case .outOfSync(let count, let reason): return "\(count) pendente(s) • \(reason)"
        case .authError(let msg): return "Erro de autenticação: \(msg)"
        case .disabled: return "Desativado"
        }
    }

    private var statusColor: Color {
        switch syncService.syncStatus {
        case .synced: return Color(hex: "#10B981")
        case .syncing: return Color(hex: "#0284C7")
        case .outOfSync: return Color(hex: "#F59E0B")
        case .authError: return Color(hex: "#EF4444")
        case .disabled: return Color.secondary
        }
    }
}
