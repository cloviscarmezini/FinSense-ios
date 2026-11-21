// Sources/FinSense/Views/Navigation/LiquidNavigationBar.swift
import SwiftUI

public struct LiquidNavigationBar: View {
    @ObservedObject var syncService: CloudSyncService
    public var title: String
    public var subtitle: String?
    public var trailingAction: (() -> Void)? = nil
    public var trailingIcon: String? = nil

    public init(
        syncService: CloudSyncService,
        title: String,
        subtitle: String? = nil,
        trailingIcon: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self.syncService = syncService
        self.title = title
        self.subtitle = subtitle
        self.trailingIcon = trailingIcon
        self.trailingAction = trailingAction
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            // Atalho global de Cenário de Planejamento de Amortização (quando houver plano salvo)
            if let store = syncService.store, store.hasAnyAmortizationPlan {
                Menu {
                    ForEach(BudgetProjectionScenario.allCases) { scenario in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.budgetProjectionScenario = scenario
                        } label: {
                            HStack {
                                Label(scenario.rawValue, systemImage: scenario.iconSymbol)
                                if store.budgetProjectionScenario == scenario {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: store.budgetProjectionScenario.iconSymbol)
                            .font(.system(size: 11, weight: .bold))
                        Text(store.budgetProjectionScenario == .withPlanning ? "Com Plano" : "Real (Base)")
                            .font(.system(size: 10.5, weight: .bold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(store.budgetProjectionScenario == .withPlanning ? Color(hex: "#8B5CF6") : Color.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(store.budgetProjectionScenario == .withPlanning ? Color(hex: "#8B5CF6").opacity(0.16) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .stroke(store.budgetProjectionScenario == .withPlanning ? Color(hex: "#8B5CF6").opacity(0.35) : Color.white.opacity(0.2), lineWidth: 0.8)
                    )
                }
            }

            // Cloud Sync Indicator Pill (Apenas quando autenticado)
            if syncService.authService?.isAuthenticated == true {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    syncService.performSync()
                } label: {
                    HStack(spacing: 6) {
                        if syncService.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: syncService.syncStatus.iconSymbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(syncStatusColor)
                        }

                        if syncService.pendingMutationsCount > 0 {
                            Text("\(syncService.pendingMutationsCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }

            if let trailingIcon, let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0284C7"))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var syncStatusColor: Color {
        switch syncService.syncStatus {
        case .synced:
            return Color(hex: "#10B981") // Verde
        case .syncing:
            return Color(hex: "#0284C7") // Azul
        case .outOfSync:
            return Color(hex: "#F59E0B") // Laranja
        case .authError:
            return Color(hex: "#EF4444") // Vermelho
        case .disabled:
            return Color.secondary
        }
    }
}
