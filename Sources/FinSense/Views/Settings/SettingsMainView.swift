// Sources/FinSense/Views/Settings/SettingsMainView.swift
import SwiftUI

public struct SettingsMainView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var aiService: CloudAIService

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        aiService: CloudAIService
    ) {
        self.store = store
        self.syncService = syncService
        self.aiService = aiService
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        LiquidNavigationBar(
                            syncService: syncService,
                            title: "Ajustes",
                            subtitle: "Configurações e conectividade"
                        )

                        // Sincronização em Nuvem
                        NavigationLink {
                            CloudSyncSettingsView(syncService: syncService, store: store)
                        } label: {
                            LiquidGlassCard(cornerRadius: 18, padding: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#0284C7").opacity(0.18))
                                            .frame(width: 42, height: 42)
                                        Image(systemName: "icloud.and.arrow.up.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color(hex: "#0284C7"))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Sincronização em Nuvem")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color.primary)
                                        Text(syncService.isEnabled ? "Sincronização ativa • Two-Way Push/Pull" : "Desativada (100% Offline)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.secondary.opacity(0.7))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        // Gestão de Modelos de IA Remota
                        NavigationLink {
                            RemoteAIManagementView(aiService: aiService, syncService: syncService)
                        } label: {
                            LiquidGlassCard(cornerRadius: 18, padding: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#8B5CF6").opacity(0.18))
                                            .frame(width: 42, height: 42)
                                        Image(systemName: "cpu.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color(hex: "#8B5CF6"))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Modelos de IA na Nuvem")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color.primary)
                                        Text("Download Hugging Face e seleção de LLMs")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.secondary.opacity(0.7))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        // Privacidade & Visual
                        LiquidGlassCard(cornerRadius: 18, padding: 16) {
                            VStack(spacing: 12) {
                                Toggle(isOn: $store.isHideBalancesEnabled) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "eye.slash.fill")
                                            .foregroundStyle(Color.secondary)
                                        Text("Ocultar Saldos por Padrão")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Informações do Aplicativo
                        LiquidGlassCard(cornerRadius: 18, padding: 16) {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Versão")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Text("1.0.0 (Build 1)")
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                }

                                Divider().opacity(0.4)

                                HStack {
                                    Text("Design System")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Text("Modern Liquid Glass")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#0284C7"))
                                }

                                Divider().opacity(0.4)

                                HStack {
                                    Text("Arquitetura")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Text("Offline-First Snapshot")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Color.clear.frame(height: 70)
                    }
                }
            }
        }
    }
}
