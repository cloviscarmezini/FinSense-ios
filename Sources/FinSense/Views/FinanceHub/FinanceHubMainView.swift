// Sources/FinSense/Views/FinanceHub/FinanceHubMainView.swift
import SwiftUI

public struct FinanceHubMainView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService

    public init(store: FinancialDataStore, syncService: CloudSyncService) {
        self.store = store
        self.syncService = syncService
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        LiquidNavigationBar(
                            syncService: syncService,
                            title: "Hub Financeiro",
                            subtitle: "Gestão completa de módulos e patrimônio"
                        )

                        // Módulos
                        VStack(spacing: 12) {
                            HubNavigationCard(
                                title: "Contas Bancárias",
                                subtitle: "\(store.accounts.count) contas • Saldo: \(AppFormatters.currency(store.totalCurrentBalance))",
                                iconSymbol: "building.columns.fill",
                                iconColor: "#0284C7"
                            ) {
                                AccountsManagerView(store: store)
                            }

                            HubNavigationCard(
                                title: "Categorias de Transações",
                                subtitle: "\(store.categories.count) categorias cadastradas",
                                iconSymbol: "square.grid.2x2.fill",
                                iconColor: "#6366F1"
                            ) {
                                CategoriesManagerView(store: store)
                            }

                            HubNavigationCard(
                                title: "Investimentos & Carteiras",
                                subtitle: "\(store.investments.count) ativos • Total: \(AppFormatters.currency(store.totalInvestedAmount))",
                                iconSymbol: "chart.line.uptrend.xyaxis.circle.fill",
                                iconColor: "#10B981"
                            ) {
                                InvestmentsManagerView(store: store)
                            }

                            HubNavigationCard(
                                title: "Dívidas & Acordos",
                                subtitle: "\(store.debts.filter { !$0.isPaid }.count) em aberto • Total: \(AppFormatters.currency(store.totalDebtAmount))",
                                iconSymbol: "exclamationmark.shield.fill",
                                iconColor: "#EF4444"
                            ) {
                                DebtsManagerView(store: store)
                            }

                            HubNavigationCard(
                                title: "Empréstimos",
                                subtitle: "\(store.contracts.filter { $0.kind == .loan }.count) ativos • Consignado e Pessoal",
                                iconSymbol: "banknote.fill",
                                iconColor: "#10B981"
                            ) {
                                CreditContractsView(store: store, kind: .loan)
                            }

                            HubNavigationCard(
                                title: "Financiamentos",
                                subtitle: "\(store.contracts.filter { $0.kind == .financing }.count) ativos • Imóvel e Carro (SAC/PRICE)",
                                iconSymbol: "house.and.flag.fill",
                                iconColor: "#F59E0B"
                            ) {
                                CreditContractsView(store: store, kind: .financing)
                            }

                            HubNavigationCard(
                                title: "Metas & Provisões",
                                subtitle: "Teto mensal por categoria e orçamento",
                                iconSymbol: "tray.full.fill",
                                iconColor: "#8B5CF6"
                            ) {
                                ProvisionsView(store: store)
                            }

                            HubNavigationCard(
                                title: "Cotas por Categoria",
                                subtitle: "\(store.categoryQuotas.count) cotas ativas com baixa automática",
                                iconSymbol: "shippingbox.fill",
                                iconColor: "#EC4899"
                            ) {
                                CategoryQuotasView(store: store)
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

public struct HubNavigationCard<Destination: View>: View {
    public let title: String
    public let subtitle: String
    public let iconSymbol: String
    public let iconColor: String
    @ViewBuilder public let destination: () -> Destination

    public var body: some View {
        NavigationLink(destination: destination) {
            LiquidGlassCard(cornerRadius: 18, padding: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: iconColor).opacity(0.18))
                            .frame(width: 42, height: 42)
                        Image(systemName: iconSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: iconColor))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.primary)
                        Text(subtitle)
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
    }
}
