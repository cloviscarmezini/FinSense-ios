// Sources/FinSense/Views/Dashboard/DashboardView.swift
import SwiftUI
import Charts

public struct DashboardView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var authService: AuthService
    @Binding var selectedTab: AppTab

    @State private var isAddTransactionSheetPresented: Bool = false
    @State private var isAddAccountSheetPresented: Bool = false
    @State private var isMonthPickerPresented: Bool = false
    @State private var isProvisionsSheetPresented: Bool = false

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        authService: AuthService,
        selectedTab: Binding<AppTab>
    ) {
        self.store = store
        self.syncService = syncService
        self.authService = authService
        self._selectedTab = selectedTab
    }

    private var isAnnual: Bool {
        store.dashboardPeriodMode == .annual
    }

    private var yearString: String {
        AppFormatters.yearString(store.selectedMonth)
    }

    private var isPastPeriod: Bool {
        if isAnnual {
            let selectedYear = store.calendar.component(.year, from: store.selectedMonth)
            let currentYear = store.calendar.component(.year, from: store.effectiveCurrentDate)
            return selectedYear < currentYear
        } else {
            return store.isMonthPriorToCurrent(store.selectedMonth)
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header com Mês Selecionado, Navegação e Status de Sync
                        headerSection

                        // Seletor de Período (Mensal vs Anual)
                        periodModeSelector

                        // Os 4 Cards de Ciclo de Vida do Orçamento (KPIs)
                        kpiCardsGrid

                        // Previsões & Tetos do Mês (quando em modo mensal)
                        if !isAnnual {
                            provisionsAndQuotasSection
                        }

                        // Gráfico de Fluxo de Caixa (Mensal ou Anual)
                        cashFlowChartCard

                        // Seção Completa de Passivos & Compromissos Futuros
                        liabilitiesSection

                        // Carrossel Horizontal de Contas Bancárias
                        AccountsCarouselView(store: store) {
                            isAddAccountSheetPresented = true
                        }

                        // Saúde Financeira
                        FinancialHealthCard(store: store, selectedMonth: store.selectedMonth)
                            .padding(.horizontal, 20)

                        // Espaçador inferior para a LiquidTabBar flutuante
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top, 10)
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
            .sheet(isPresented: $isProvisionsSheetPresented) {
                NavigationStack {
                    ProvisionsView(store: store)
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FinSense")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                HStack(spacing: 6) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isAnnual {
                            store.changeYear(by: -1)
                        } else {
                            store.changeMonth(by: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isMonthPickerPresented = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(isAnnual ? "Ano \(yearString)" : AppFormatters.monthYear(store.selectedMonth))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#0284C7"))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: "#0284C7"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isAnnual {
                            store.changeYear(by: 1)
                        } else {
                            store.changeMonth(by: 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Indicador de Sync (apenas quando logado)
            if authService.isAuthenticated {
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
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }

            // Botão Nova Transação
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isAddTransactionSheetPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(Circle().fill(Color(hex: "#0284C7")))
                    .shadow(color: Color(hex: "#0284C7").opacity(0.4), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Period Mode Selector
    private var periodModeSelector: some View {
        Picker("Período", selection: $store.dashboardPeriodMode) {
            Text("Mensal").tag(DashboardPeriodMode.monthly)
            Text("Anual").tag(DashboardPeriodMode.annual)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .onChange(of: store.dashboardPeriodMode) { _, newMode in
            if newMode == .annual {
                store.ensureRecurringTransactionsMaterialized(upTo: store.endOfYear(for: store.selectedMonth))
            } else {
                store.ensureRecurringTransactionsMaterialized(upTo: store.endOfMonth(for: store.selectedMonth))
            }
        }
    }

    // MARK: - 4 Lifecycle KPI Cards
    private var kpiCardsGrid: some View {
        let periodIncome = isAnnual
            ? store.annualIncome(for: store.selectedMonth)
            : store.monthlyIncome(for: store.selectedMonth)
        let periodReceivedIncome = isAnnual
            ? store.annualReceivedIncome(for: store.selectedMonth)
            : store.monthlyReceivedIncome(for: store.selectedMonth)
        let periodPendingIncome = isAnnual
            ? store.annualPendingIncome(for: store.selectedMonth)
            : store.monthlyPendingIncome(for: store.selectedMonth)

        let periodExpense = isAnnual
            ? store.annualExpense(for: store.selectedMonth)
            : store.monthlyExpense(for: store.selectedMonth)
        let periodPaidExpense = isAnnual
            ? store.annualPaidExpense(for: store.selectedMonth)
            : store.monthlyPaidExpense(for: store.selectedMonth)
        let periodPendingExpense = isAnnual
            ? store.annualPendingExpense(for: store.selectedMonth)
            : store.monthlyPendingExpense(for: store.selectedMonth)

        let periodNet = periodIncome - periodExpense
        let savingsRate: Double? = periodIncome > 0 ? ((periodNet / periodIncome) * 100.0) : nil

        let accumulatedBalance = isAnnual
            ? store.accumulatedConsolidatedBalanceThroughYear(store.selectedMonth)
            : store.accumulatedConsolidatedBalance(throughMonth: store.selectedMonth)

        let finalTitle = isAnnual
            ? (isPastPeriod ? "Resultado Consolidado" : "Saldo Previsto 31/12/\(yearString)")
            : store.monthEndBalanceCardTitle(for: store.selectedMonth)

        let finalSubtitle = store.deductionSubtitleForProjectedBalance(
            periodMode: store.dashboardPeriodMode,
            selectedMonth: store.selectedMonth
        )

        let operationalSubtitle: String = {
            if let rate = savingsRate {
                return rate >= 0
                    ? String(format: "%.1f%% sobre receitas", rate)
                    : String(format: "Déficit (%.1f%%)", abs(rate))
            } else {
                return periodNet >= 0 ? "Superávit operacional" : "Déficit operacional"
            }
        }()

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // Card 1: Receitas
            kpiCard(
                title: isAnnual ? "Receitas do Ano" : "Receitas do Mês",
                value: AppFormatters.currency(periodIncome),
                subtitle: "\(AppFormatters.currency(periodReceivedIncome)) rec. • \(AppFormatters.currency(periodPendingIncome)) pend.",
                icon: "arrow.down.left.circle.fill",
                tint: Color(hex: "#10B981")
            )

            // Card 2: Despesas
            kpiCard(
                title: isAnnual ? "Despesas do Ano" : "Despesas do Mês",
                value: AppFormatters.currency(periodExpense),
                subtitle: "\(AppFormatters.currency(periodPaidExpense)) pagas • \(AppFormatters.currency(periodPendingExpense)) pend.",
                icon: "arrow.up.right.circle.fill",
                tint: Color(hex: "#EF4444")
            )

            // Card 3: Balanço Operacional
            kpiCard(
                title: "Balanço Operacional",
                value: AppFormatters.currency(periodNet),
                subtitle: operationalSubtitle,
                icon: "equal.circle.fill",
                tint: periodNet >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444")
            )

            // Card 4: Saldo Projetado
            kpiCard(
                title: finalTitle,
                value: AppFormatters.currency(accumulatedBalance),
                subtitle: finalSubtitle,
                icon: isPastPeriod ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis",
                tint: accumulatedBalance >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"),
                alertText: (!isPastPeriod && accumulatedBalance < 0) ? "Risco de caixa negativo" : nil
            )
        }
        .padding(.horizontal, 20)
    }

    private func kpiCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        alertText: String? = nil
    ) -> some View {
        LiquidGlassCard(cornerRadius: 18, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let alertText {
                    Text(alertText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: "#EF4444"))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Previsões & Tetos do Mês
    private var provisionsAndQuotasSection: some View {
        let estimatedProvisionsTotal = store.totalEstimatedProvision(for: store.selectedMonth)
        let remainingProvisionsTotal = isPastPeriod ? 0.0 : store.totalRemainingProvision(for: store.selectedMonth)
        let monthEnvelopes = store.provisionEnvelopes(for: store.selectedMonth)
        let monthQuotas = store.allQuotaEnvelopes(for: store.selectedMonth)
        let hasAny = !monthEnvelopes.isEmpty || !monthQuotas.isEmpty

        return LiquidGlassCard(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#6366F1"))
                        Text("Previsões & Tetos do Mês")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primary)
                    }

                    Spacer()

                    Button {
                        isProvisionsSheetPresented = true
                    } label: {
                        Text(hasAny ? "Gerenciar" : "Configurar")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#6366F1"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: "#6366F1").opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Orçado")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                        Text(AppFormatters.currency(estimatedProvisionsTotal))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.primary)
                    }

                    Divider().frame(height: 24).opacity(0.4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Provisão Restante")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                        Text(AppFormatters.currency(remainingProvisionsTotal))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#6366F1"))
                    }

                    Spacer()

                    Text("\(monthEnvelopes.count) teto(s) • \(monthQuotas.count) cota(s)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Gráfico de Fluxo de Caixa (Swift Charts)
    private var cashFlowChartCard: some View {
        let points = isAnnual
            ? store.annualCashFlowSeries(for: store.selectedMonth)
            : store.cashFlowSeries(around: store.selectedMonth, monthsBack: 2, monthsForward: 3)

        return LiquidGlassCard(cornerRadius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isAnnual ? "Projeção Anual (\(yearString))" : "Fluxo de Caixa Mensal")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primary)
                        Text(isAnnual ? "Receitas vs despesas mês a mês" : "Comparativo entre meses adjacentes")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle().fill(Color(hex: "#10B981")).frame(width: 6, height: 6)
                            Text("Rec").font(.system(size: 9.5)).foregroundStyle(Color.secondary)
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Color(hex: "#EF4444")).frame(width: 6, height: 6)
                            Text("Desp").font(.system(size: 9.5)).foregroundStyle(Color.secondary)
                        }
                        HStack(spacing: 3) {
                            Capsule().fill(Color(hex: "#3B82F6")).frame(width: 8, height: 3)
                            Text("Saldo").font(.system(size: 9.5)).foregroundStyle(Color.secondary)
                        }
                    }
                }

                if points.isEmpty {
                    Text("Sem dados de movimentação para o período.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Chart {
                        ForEach(points) { pt in
                            // Barra de Receitas
                            BarMark(
                                x: .value("Mês", pt.label),
                                y: .value("Receitas", pt.income)
                            )
                            .foregroundStyle(Color(hex: "#10B981"))
                            .position(by: .value("Tipo", "Receitas"))
                            .cornerRadius(3)

                            // Barra de Despesas lançadas
                            BarMark(
                                x: .value("Mês", pt.label),
                                yStart: .value("Base", 0),
                                yEnd: .value("Despesas", pt.expense)
                            )
                            .foregroundStyle(Color(hex: "#EF4444"))
                            .position(by: .value("Tipo", "Despesas"))
                            .cornerRadius(!pt.isPastMonth && pt.remainingProvisions > 0 ? 0 : 3)

                            // Topo translúcido: Previsões restantes
                            if !pt.isPastMonth && pt.remainingProvisions > 0 {
                                BarMark(
                                    x: .value("Mês", pt.label),
                                    yStart: .value("Base", pt.expense),
                                    yEnd: .value("Total", pt.totalBudgetedExpense)
                                )
                                .foregroundStyle(Color(hex: "#EF4444").opacity(0.45))
                                .position(by: .value("Tipo", "Despesas"))
                                .cornerRadius(3)
                            }

                            // Linha de Saldo Acumulado
                            LineMark(
                                x: .value("Mês", pt.label),
                                y: .value("Saldo", pt.accumulatedBalance)
                            )
                            .foregroundStyle(Color(hex: "#3B82F6"))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Mês", pt.label),
                                y: .value("Saldo", pt.accumulatedBalance)
                            )
                            .foregroundStyle(Color(hex: "#3B82F6"))
                            .symbolSize(22)
                        }
                    }
                    .frame(height: 170)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Passivos & Compromissos Futuros
    private var liabilitiesSection: some View {
        let debtSummary = store.buildComprehensiveDebtSummary(
            referenceDate: store.selectedMonth,
            isAnnual: isAnnual
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Passivos & Compromissos")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text("Dívidas, contratos e parcelas a vencer")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Total a Quitar (PV)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Text(AppFormatters.currency(debtSummary.grandTotalWithPayoffProjection))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#EF4444"))
                    if abs(debtSummary.grandTotalNominal - debtSummary.grandTotalWithPayoffProjection) > 0.01 {
                        Text("Nominal: \(AppFormatters.currency(debtSummary.grandTotalNominal))")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Carrossel dos 5 Pilares de Passivos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    debtPillarMiniCard(
                        title: isAnnual ? "Pendentes no Ano" : "Transações Atuais",
                        subtitle: "\(debtSummary.currentMonthUnpaidTransactions.count) pendente(s)",
                        amount: debtSummary.currentMonthUnpaidTotal,
                        icon: "calendar.badge.exclamationmark",
                        colorHex: "#F59E0B"
                    )

                    debtPillarMiniCard(
                        title: "Transações Futuras",
                        subtitle: "\(debtSummary.futureUnpaidRegularTransactions.count) agendada(s)",
                        amount: debtSummary.futureRegularExpensesTotal,
                        icon: "clock.arrow.circlepath",
                        colorHex: "#3B82F6"
                    )

                    debtPillarMiniCard(
                        title: "Dívidas (Acordos)",
                        subtitle: "\(debtSummary.activeDebts.count) dívida(s)",
                        amount: debtSummary.unpaidDebtsTotal,
                        icon: "exclamationmark.triangle.fill",
                        colorHex: "#EF4444"
                    )

                    debtPillarMiniCard(
                        title: "Empréstimos",
                        subtitle: "\(debtSummary.activeLoans.count) contrato(s)",
                        amount: debtSummary.loansProjectedPayoffTotal,
                        nominal: debtSummary.loansRemainingNominalTotal,
                        icon: "banknote.fill",
                        colorHex: "#D97706"
                    )

                    debtPillarMiniCard(
                        title: "Financiamentos",
                        subtitle: "\(debtSummary.activeFinancings.count) contrato(s)",
                        amount: debtSummary.financingsProjectedPayoffTotal,
                        nominal: debtSummary.financingsRemainingNominalTotal,
                        icon: "house.and.flag.fill",
                        colorHex: "#8B5CF6"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    private func debtPillarMiniCard(
        title: String,
        subtitle: String,
        amount: Double,
        nominal: Double? = nil,
        icon: String,
        colorHex: String
    ) -> some View {
        LiquidGlassCard(cornerRadius: 18, padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: colorHex))
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }

                Text(AppFormatters.currency(amount))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: colorHex))
                    .monospacedDigit()
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)

                if let nominal, abs(nominal - amount) > 0.01 {
                    Text("Nominal: \(AppFormatters.currency(nominal))")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .frame(width: 145, alignment: .leading)
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

// MARK: - MonthPickerSheet

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
