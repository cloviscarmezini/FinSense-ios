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

            // Cloud Sync Indicator Pill (passivo: apenas exibe status)
            if syncService.authService?.isAuthenticated == true {
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

/// Barra dedicada e espaçosa para navegação entre meses/anos no Dashboard e no Extrato.
public struct PeriodNavigatorBar: View {
    public let title: String
    public let isCurrentPeriod: Bool
    public let onPrevious: () -> Void
    public let onNext: () -> Void
    public let onSelectPeriod: () -> Void
    public let onJumpToToday: () -> Void

    public init(
        title: String,
        isCurrentPeriod: Bool,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onSelectPeriod: @escaping () -> Void,
        onJumpToToday: @escaping () -> Void
    ) {
        self.title = title
        self.isCurrentPeriod = isCurrentPeriod
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onSelectPeriod = onSelectPeriod
        self.onJumpToToday = onJumpToToday
    }

    public var body: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSelectPeriod()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#0284C7"))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(Color(hex: "#0284C7").opacity(0.14))
                        .overlay(Capsule().stroke(Color(hex: "#0284C7").opacity(0.28), lineWidth: 0.9))
                )
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)

            if !isCurrentPeriod {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onJumpToToday()
                } label: {
                    Text("Hoje")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#0284C7"))
                        .frame(height: 38)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}
