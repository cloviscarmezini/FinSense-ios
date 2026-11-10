// Sources/FinSense/Views/Settings/SettingsMainView.swift
import SwiftUI

public struct SettingsMainView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var authService: AuthService

    @State private var isAuthSheetPresented: Bool = false
    @State private var isLogoutConfirmationPresented: Bool = false
    @State private var isResetSheetPresented: Bool = false

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        authService: AuthService
    ) {
        self.store = store
        self.syncService = syncService
        self.authService = authService
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

                        // MARK: - Seção de Conta / Autenticação
                        if authService.isAuthenticated {
                            authenticatedAccountCard
                        } else {
                            unauthenticatedAccountCard
                        }

                        // MARK: - Sincronização em Nuvem (Apenas visível se autenticado)
                        if authService.isAuthenticated {
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
                        }

                        // MARK: - Privacidade & Visual
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

                        // MARK: - Gestão da Base de Dados (Recomeçar do Zero)
                        LiquidGlassCard(cornerRadius: 18, padding: 16) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                isResetSheetPresented = true
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#EF4444").opacity(0.18))
                                            .frame(width: 42, height: 42)
                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color(hex: "#EF4444"))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Recomeçar do Zero")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color(hex: "#EF4444"))
                                        Text("Limpar transações, contas e categorias")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.secondary.opacity(0.7))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Informações do Aplicativo
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
                                    Text("Status da Aplicação")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Text(authService.isAuthenticated ? "Nuvem & IA Ativos" : "100% Local (Offline)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(authService.isAuthenticated ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
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
            .sheet(isPresented: $isAuthSheetPresented) {
                AuthSheetView(authService: authService, baseURL: syncService.baseURLString) {
                    syncService.performSync()
                }
            }
            .sheet(isPresented: $isResetSheetPresented) {
                ResetFromScratchIOSSheet(store: store, syncService: syncService, authService: authService)
            }
            .confirmationDialog(
                "Deseja realmente sair da sua conta?",
                isPresented: $isLogoutConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Encerrar Sessão", role: .destructive) {
                    Task {
                        await authService.logout(baseURL: syncService.baseURLString)
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Ao desconectar, o acesso à IA será pausado e os dados permanecerão salvos localmente no seu dispositivo.")
            }
        }
    }

    // MARK: - Cartão para Usuário Não Autenticado
    private var unauthenticatedAccountCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            isAuthSheetPresented = true
        } label: {
            LiquidGlassCard(cornerRadius: 18, padding: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#0284C7"), Color(hex: "#38BDF8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 46, height: 46)

                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Entrar ou Criar Conta")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.primary)
                        Text("Conecte sua conta para habilitar IA e Sincronização")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
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
    }

    // MARK: - Cartão de Perfil Autenticado
    private var authenticatedAccountCard: some View {
        LiquidGlassCard(cornerRadius: 18, padding: 16) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#10B981").opacity(0.18))
                            .frame(width: 46, height: 46)

                        Text(userInitials)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(authService.currentUser?.fullName ?? "Usuário FinSense")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.primary)

                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: "#10B981"))
                                    .frame(width: 6, height: 6)
                                Text("Online")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "#10B981").opacity(0.15)))
                        }

                        Text(authService.currentUser?.email ?? "")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()
                }

                Divider().opacity(0.4)

                HStack {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isLogoutConfirmationPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Encerrar Sessão")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "#EF4444"))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var userInitials: String {
        guard let name = authService.currentUser?.fullName, !name.isEmpty else {
            return "FS"
        }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

// MARK: - Sheet: Recomeçar do Zero no iOS
struct ResetFromScratchIOSSheet: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var resetCloudData: Bool = false
    @State private var isResetting: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color(hex: "#EF4444"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Atenção")
                                    .font(.headline)
                                Text("Esta ação limpará os dados da sua base no dispositivo.")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Opções") {
                    Toggle(isOn: $resetCloudData) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zerar dados na nuvem também")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(resetCloudData ? Color(hex: "#EF4444") : Color.primary)
                            Text(authService.isAuthenticated
                                ? "Remove os dados persistidos no servidor da sua conta conectada."
                                : "Disponível apenas quando conectado a uma conta FinSense.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .disabled(!authService.isAuthenticated || isResetting)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        executeReset()
                    } label: {
                        HStack {
                            Spacer()
                            if isResetting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text(resetCloudData ? "Confirmar e Zerar Base Local e Nuvem" : "Confirmar e Recomeçar do Zero")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isResetting)
                }
            }
            .navigationTitle("Recomeçar do Zero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isResetting)
                }
            }
        }
    }

    private func executeReset() {
        if resetCloudData && authService.isAuthenticated {
            isResetting = true
            errorMessage = nil
            Task {
                do {
                    try await syncService.resetCloudData()
                    await MainActor.run {
                        store.resetAllData()
                        isResetting = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isResetting = false
                        errorMessage = "Falha ao zerar dados na nuvem: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            store.resetAllData()
            dismiss()
        }
    }
}
