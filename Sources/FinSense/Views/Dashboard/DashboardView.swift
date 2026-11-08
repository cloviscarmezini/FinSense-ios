// Sources/FinSense/Views/Dashboard/DashboardView.swift
import SwiftUI

public struct DashboardView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @Binding var selectedTab: AppTab

    @State private var isAddTransactionSheetPresented: Bool = false
    @State private var isAddAccountSheetPresented: Bool = false
    @State private var isMonthPickerPresented: Bool = false

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        selectedTab: Binding<AppTab>
    ) {
        self.store = store
        self.syncService = syncService
        self._selectedTab = selectedTab
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header com Mês Selecionado e Status de Sync
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FinSense")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.primary)

                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    isMonthPickerPresented = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(AppFormatters.monthYear(store.selectedMonth))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#0284C7"))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color(hex: "#0284C7"))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            // Indicador de Sincronização
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
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(syncStatusColor)
                                    }

                                    if syncService.pendingMutationsCount > 0 {
                                        Text("\(syncService.pendingMutationsCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.primary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)

                            // Botão Nova Transação Rápida
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                isAddTransactionSheetPresented = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color(hex: "#0284C7")))
                                    .shadow(color: Color(hex: "#0284C7").opacity(0.4), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        // Banner de Saldo Consolidado
                        LiquidGlassCard(cornerRadius: 22, padding: 18) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Patrimônio Líquido em Contas")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.secondary)

                                    if store.isHideBalancesEnabled {
                                        Text("R$ ••••••••")
                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.primary)
                                    } else {
                                        Text(AppFormatters.currency(store.totalCurrentBalance))
                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                            .foregroundStyle(store.totalCurrentBalance >= 0 ? Color.primary : Color(hex: "#EF4444"))
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 6) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(hex: "#10B981"))
                                        Text(AppFormatters.currency(store.totalInvestedAmount))
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.primary)
                                    }

                                    if store.totalDebtAmount > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.shield.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color(hex: "#EF4444"))
                                            Text(AppFormatters.currency(store.totalDebtAmount))
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(Color(hex: "#EF4444"))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Card Circular de Saúde Financeira
                        FinancialHealthCard(store: store, selectedMonth: store.selectedMonth)
                            .padding(.horizontal, 20)

                        // Carrossel Horizontal de Contas
                        AccountsCarouselView(store: store) {
                            isAddAccountSheetPresented = true
                        }

                        // Resumo Operacional de Fluxo de Caixa
                        MonthlyCashFlowCard(store: store, selectedMonth: store.selectedMonth)
                            .padding(.horizontal, 20)

                        // Financiamentos e Dívidas Ativas
                        if !store.contracts.isEmpty || !store.debts.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Compromissos & Amortização")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.primary)

                                    Spacer()

                                    Button {
                                        withAnimation {
                                            selectedTab = .financeHub
                                        }
                                    } label: {
                                        Text("Ver Todos")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#0284C7"))
                                    }
                                }
                                .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(store.contracts) { contract in
                                            LiquidGlassCard(cornerRadius: 18, padding: 14) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    HStack {
                                                        Image(systemName: contract.iconSymbol)
                                                            .font(.system(size: 13, weight: .bold))
                                                            .foregroundStyle(Color(hex: "#0284C7"))
                                                        Text(contract.name)
                                                            .font(.system(size: 13, weight: .bold))
                                                            .lineLimit(1)
                                                    }

                                                    Text("Saldo Devedor: \(AppFormatters.currency(contract.outstandingBalance ?? contract.totalContractedAmount))")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(Color.secondary)

                                                    HStack {
                                                        Text("Parcela: \(AppFormatters.currency(contract.installmentAmount))")
                                                            .font(.system(size: 11, weight: .semibold))
                                                            .foregroundStyle(Color.primary)
                                                        Spacer()
                                                        Text(contract.amortizationSystem == .sac ? "SAC" : "PRICE")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Capsule().fill(Color.primary.opacity(0.1)))
                                                    }
                                                }
                                                .frame(width: 200)
                                            }
                                        }

                                        ForEach(store.debts.filter { !$0.isPaid }) { debt in
                                            LiquidGlassCard(cornerRadius: 18, padding: 14) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    HStack {
                                                        Image(systemName: debt.iconSymbol)
                                                            .font(.system(size: 13, weight: .bold))
                                                            .foregroundStyle(Color(hex: "#EF4444"))
                                                        Text(debt.name)
                                                            .font(.system(size: 13, weight: .bold))
                                                            .lineLimit(1)
                                                    }

                                                    Text("Valor: \(AppFormatters.currency(debt.originalAmount))")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(Color.secondary)

                                                    if let negotiated = debt.negotiatedAmount {
                                                        Text("Acordo: \(AppFormatters.currency(negotiated))")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundStyle(Color(hex: "#10B981"))
                                                    }
                                                }
                                                .frame(width: 170)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // Espaçador inferior para a LiquidTabBar flutuante
                        Color.clear.frame(height: 70)
                    }
                }
            }
            .sheet(isPresented: $isAddTransactionSheetPresented) {
                TransactionDetailSheet(store: store, syncService: syncService)
            }
            .sheet(isPresented: $isAddAccountSheetPresented) {
                AccountEditorSheet(store: store)
            }
            .sheet(isPresented: $isMonthPickerPresented) {
                MonthPickerSheet(selectedMonth: $store.selectedMonth)
            }
        }
    }

    private var syncStatusColor: Color {
        switch syncService.syncStatus {
        case .synced: return Color(hex: "#10B981")
        case .syncing: return Color(hex: "#0284C7")
        case .outOfSync: return Color(hex: "#F59E0B")
        case .authError: return Color(hex: "#EF4444")
        case .disabled: return Color.secondary
        }
    }
}

public struct MonthPickerSheet: View {
    @Binding public var selectedMonth: Date
    @Environment(\.dismiss) var dismiss

    public init(selectedMonth: Binding<Date>) {
        self._selectedMonth = selectedMonth
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Selecione o Mês",
                    selection: $selectedMonth,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Selecionar Mês")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
