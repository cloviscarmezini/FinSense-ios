// Sources/FinSense/Views/Transactions/TransactionsListView.swift
import SwiftUI

public enum TransactionFilterTab: String, CaseIterable, Identifiable {
    case all = "Todos"
    case expenses = "Despesas"
    case incomes = "Receitas"
    case pending = "Pendentes"

    public var id: String { rawValue }
}

public struct TransactionsListView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var authService: AuthService

    @State private var selectedFilter: TransactionFilterTab = .all
    @State private var searchText: String = ""
    @State private var isSearchVisible: Bool = false
    @State private var isAddSheetPresented: Bool = false
    @State private var isMonthPickerPresented: Bool = false
    @State private var editingTransaction: FinancialTransaction? = nil
    @State private var confirmingInstallmentPaymentTx: FinancialTransaction? = nil

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

                VStack(spacing: 12) {
                    // Header de Navegação
                    LiquidNavigationBar(
                        syncService: syncService,
                        title: "Extrato",
                        subtitle: nil,
                        trailingIcon: "plus"
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isAddSheetPresented = true
                    }

                    // Seletor e Navegação de Mês
                    HStack(spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.changeMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(7)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isMonthPickerPresented = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(AppFormatters.monthYear(store.selectedMonth))
                                    .font(.system(size: 13, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: "#0284C7"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.changeMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(7)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if !store.isInMonth(Date(), monthReference: store.selectedMonth) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                store.selectedMonth = Date()
                            } label: {
                                Text("Hoje")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#0284C7"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Cards de Resumo Rápido do Filtro
                    filterSummaryCards

                    // Pílulas Deslizantes de Filtro
                    HStack(spacing: 8) {
                        ForEach(TransactionFilterTab.allCases) { tab in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedFilter = tab
                                }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedFilter == tab ? .bold : .medium))
                                    .foregroundStyle(selectedFilter == tab ? .white : Color.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background {
                                        if selectedFilter == tab {
                                            Capsule()
                                                .fill(Color(hex: "#0284C7"))
                                        } else {
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Campo de Busca (revelado ao puxar a tela para baixo)
                    if isSearchVisible || !searchText.isEmpty {
                        searchBarView
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Lista de Transações com detecção de scroll
                    ScrollView {
                        // Marcador para detecção de scroll down
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("extratoScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        if filteredGroupedDays.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.secondary.opacity(0.4))
                                Text("Nenhuma transação encontrada")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            .padding(.bottom, 72)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredGroupedDays, id: \.date) { group in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Header do Dia
                                        HStack {
                                            Text(AppFormatters.dayGroupHeader(group.date))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.secondary)

                                            Spacer()

                                            Text(AppFormatters.currency(group.netAmount))
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundStyle(group.netAmount >= 0 ? Color(hex: "#10B981") : Color.secondary)
                                        }
                                        .padding(.horizontal, 24)

                                        // Linhas do Dia
                                        ForEach(group.transactions) { tx in
                                            TransactionRow(
                                                transaction: tx,
                                                store: store,
                                                onTap: {
                                                    editingTransaction = tx
                                                },
                                                onTogglePaid: {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    if !tx.isPaid && store.installmentCorrectionBreakdown(for: tx) != nil {
                                                        confirmingInstallmentPaymentTx = tx
                                                    } else {
                                                        store.toggleTransactionPaid(transactionId: tx.id)
                                                    }
                                                }
                                            )
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 72)
                        }
                    }
                    .coordinateSpace(name: "extratoScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        if offset > 25 && !isSearchVisible {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isSearchVisible = true
                            }
                        } else if offset < -60 && isSearchVisible && searchText.isEmpty {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isSearchVisible = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                TransactionDetailSheet(store: store, syncService: syncService)
            }
            .sheet(isPresented: $isMonthPickerPresented) {
                MonthPickerSheet(selectedMonth: $store.selectedMonth)
            }
            .sheet(item: $editingTransaction) { tx in
                TransactionDetailSheet(store: store, syncService: syncService, editingTransaction: tx)
            }
            .sheet(item: $confirmingInstallmentPaymentTx) { tx in
                ConfirmInstallmentPaymentModalSheet(store: store, transaction: tx)
            }
        }
    }

    // MARK: - Barra de Busca Retrátil
    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)

            TextField("Buscar por nome, conta ou valor...", text: $searchText)
                .font(.system(size: 14))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            } else if isSearchVisible {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSearchVisible = false
                    }
                } label: {
                    Text("Cancelar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0284C7"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Cards Resumo do Filtro
    private var filterSummaryCards: some View {
        let summary = store.buildUnifiedFinancialKPISummary(referenceDate: store.selectedMonth, isAnnual: false)

        let (leftTitle, leftAmount, leftColor, leftIcon, rightTitle, rightAmount, rightColor, rightIcon): (String, Double, String, String, String, Double, String, String) = {
            switch selectedFilter {
            case .all:
                return (
                    "Saldo em contas", summary.currentAccountBalanceNow, "#0284C7", "building.columns.fill",
                    summary.isPast ? "Resultado fechado" : "Balanço do mês", summary.transactionsNetBalance, summary.transactionsNetBalance >= 0 ? "#10B981" : "#EF4444", "chart.line.uptrend.xyaxis"
                )
            case .expenses:
                return (
                    "Total pago", summary.paidExpense, "#EF4444", "creditcard.fill",
                    "Total pendente", summary.pendingExpense, summary.pendingExpense > 0 ? "#EF4444" : "#10B981", "clock.fill"
                )
            case .incomes:
                return (
                    "Total de receitas", summary.projectedIncome, "#10B981", "arrow.down.left.circle.fill",
                    "Total recebido", summary.receivedIncome, "#059669", "checkmark.circle.fill"
                )
            case .pending:
                return (
                    "Despesas pendentes", summary.pendingExpense, "#EF4444", "exclamationmark.circle.fill",
                    "Receitas pendentes", summary.pendingIncome, "#10B981", "hourglass"
                )
            }
        }()

        return HStack(spacing: 12) {
            summaryMiniCard(title: leftTitle, amount: leftAmount, colorHex: leftColor, icon: leftIcon)
            summaryMiniCard(title: rightTitle, amount: rightAmount, colorHex: rightColor, icon: rightIcon)
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedFilter)
    }

    private func summaryMiniCard(title: String, amount: Double, colorHex: String, icon: String) -> some View {
        LiquidGlassCard(cornerRadius: 16, padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: colorHex))
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Text(AppFormatters.currency(amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct DayGroup {
        let date: Date
        let transactions: [FinancialTransaction]
        let netAmount: Double
    }

    private var filteredGroupedDays: [DayGroup] {
        let cal = Calendar.current
        var list = store.transactions(for: store.selectedMonth)
            .filter { store.isTransactionVisibleInCurrentScenario($0) }

        // Filtro por Segmento
        switch selectedFilter {
        case .all: break
        case .expenses: list = list.filter { $0.type == .expense }
        case .incomes: list = list.filter { $0.type == .income }
        case .pending: list = list.filter { !$0.isPaid }
        }

        // Busca
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.details.lowercased().contains(query) ||
                String(format: "%.2f", $0.amount).contains(query)
            }
        }

        // Agrupamento por dia (normalizado meia-noite)
        let grouped = Dictionary(grouping: list) { tx -> Date in
            cal.startOfDay(for: tx.date)
        }

        return grouped.keys.sorted(by: >).map { date in
            let dayTxs = grouped[date]!.sorted(by: { $0.date > $1.date })
            let dayNet = dayTxs.reduce(0.0) { $0 + store.effectiveSignedTransactionAmount(for: $1) }
            return DayGroup(date: date, transactions: dayTxs, netAmount: dayNet)
        }
    }
}

public struct TransactionRow: View {
    public let transaction: FinancialTransaction
    @ObservedObject public var store: FinancialDataStore
    public var onTap: () -> Void
    public var onTogglePaid: (() -> Void)? = nil

    public var body: some View {
        let cat = store.categories.first(where: { $0.id == transaction.categoryId })
        let acc = store.accounts.first(where: { $0.id == transaction.accountId })
        let projStatus = store.transactionProjectionStatus(for: transaction)
        let isFullPayoffTx = store.isPlannedAmortizationFullPayoff(transaction)
        let effectiveAmount = store.effectiveTransactionAmount(for: transaction)
        let isShadowed = projStatus == .shadowed
        let correctionBreakdown = store.installmentCorrectionBreakdown(for: transaction)

        LiquidGlassCard(cornerRadius: 16, padding: 12) {
            HStack(spacing: 12) {
                if let onTogglePaid {
                    Button(action: onTogglePaid) {
                        Image(systemName: transaction.isPaid ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(transaction.isPaid ? Color(hex: "#10B981") : Color.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onTap) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((isFullPayoffTx ? Color(hex: "#10B981") : Color(hex: cat?.colorHex ?? "#3B82F6")).opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: isFullPayoffTx ? "checkmark.seal.fill" : (cat?.iconSymbol ?? "tag.fill"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(isFullPayoffTx ? Color(hex: "#10B981") : Color(hex: cat?.colorHex ?? "#3B82F6"))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(transaction.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isShadowed ? Color.secondary : (isFullPayoffTx ? Color(hex: "#10B981") : Color.primary))
                                .strikethrough(isShadowed, color: .secondary)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                if let acc {
                                    Text(acc.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }

                                if let badge = transaction.installmentBadge {
                                    Text(badge)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                                        .foregroundStyle(Color.secondary)
                                }

                                if isFullPayoffTx {
                                    Text("Liquidação Planejada (Quitação Total)")
                                        .font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(Capsule().fill(Color(hex: "#10B981").opacity(0.22)))
                                        .foregroundStyle(Color(hex: "#10B981"))
                                } else if projStatus == .pendingAmortization {
                                    Text("Amortização Planejada")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(Capsule().fill(Color(hex: "#8B5CF6").opacity(0.18)))
                                        .foregroundStyle(Color(hex: "#8B5CF6"))
                                } else if isShadowed {
                                    Text("Suprimida pelo Plano (R$ 0,00)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(Capsule().fill(Color(hex: "#10B981").opacity(0.16)))
                                        .foregroundStyle(Color(hex: "#10B981"))
                                } else if !transaction.isPaid {
                                    Text("Pendente")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color(hex: "#F59E0B").opacity(0.18)))
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                }
                            }

                            if let breakdown = correctionBreakdown {
                                if let confirmed = breakdown.confirmedRealCorrectionAmount, transaction.isPaid {
                                    Text("Base: \(AppFormatters.currency(breakdown.baseRegisteredAmount)) • Juros/Correção Efetivada: +\(AppFormatters.currency(confirmed))")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#10B981"))
                                        .lineLimit(1)
                                } else {
                                    Text("Base: \(AppFormatters.currency(breakdown.baseRegisteredAmount)) • Projeção (+\(breakdown.futureMonthStep)m): +\(AppFormatters.currency(breakdown.projectedCorrectionAmount))")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(AppFormatters.currency(effectiveAmount))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(
                                    isShadowed
                                        ? Color(hex: "#10B981")
                                        : (isFullPayoffTx ? Color(hex: "#10B981") : (transaction.type == .income ? Color(hex: "#10B981") : Color.primary))
                                )

                            if isShadowed {
                                Text(AppFormatters.currency(transaction.amount))
                                    .font(.system(size: 10, design: .monospaced))
                                    .strikethrough(true, color: .secondary)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isFullPayoffTx ? Color(hex: "#10B981").opacity(0.55) : Color.clear, lineWidth: 1.3)
        )
    }
}

// MARK: - Modal para Confirmar Valor Real Final de Parcela com Correção Projetada (Caixa TP)

public struct ConfirmInstallmentPaymentModalSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let transaction: FinancialTransaction
    @Environment(\.dismiss) var dismiss

    @State private var finalPaidAmountText: String = ""

    public init(store: FinancialDataStore, transaction: FinancialTransaction) {
        self.store = store
        self.transaction = transaction
        _finalPaidAmountText = State(initialValue: AppFormatters.currency(transaction.amount))
    }

    private var breakdown: InstallmentCorrectionBreakdown? {
        store.installmentCorrectionBreakdown(for: transaction)
    }

    private var baseAmount: Double {
        breakdown?.baseRegisteredAmount ?? transaction.baseInstallmentRegisteredAmount ?? transaction.amount
    }

    private var projectedCorrection: Double {
        breakdown?.projectedCorrectionAmount ?? transaction.projectedInstallmentCorrectionAmount ?? max(0.0, transaction.amount - baseAmount)
    }

    private var parsedFinalAmount: Double {
        AppFormatters.parseAmount(finalPaidAmountText) ?? transaction.amount
    }

    private var effectiveCorrectionOnOccasion: Double {
        max(0.0, parsedFinalAmount - baseAmount)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Composição da Parcela") {
                    HStack {
                        Text("Parcela Base Cadastrada")
                        Spacer()
                        Text(AppFormatters.currency(baseAmount))
                            .font(.system(.body, design: .monospaced))
                            .bold()
                    }

                    HStack {
                        Text("Correção/Juros Projetado")
                        Spacer()
                        Text("+\(AppFormatters.currency(projectedCorrection))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color(hex: "#F59E0B"))
                    }

                    HStack {
                        Text("Total Projetado no Fechamento")
                        Spacer()
                        Text(AppFormatters.currency(baseAmount + projectedCorrection))
                            .font(.system(.body, design: .monospaced))
                            .bold()
                    }
                }

                Section("Confirmação do Pagamento Efetivo") {
                    HStack {
                        Text("Valor Real Final Pago")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $finalPaidAmountText)
                    }

                    HStack {
                        Text("Juros / Correção Efetivada na Ocasião")
                        Spacer()
                        Text("+\(AppFormatters.currency(effectiveCorrectionOnOccasion))")
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .foregroundStyle(Color(hex: "#10B981"))
                    }

                    HStack(spacing: 8) {
                        Button("Usar Projetado") {
                            finalPaidAmountText = AppFormatters.currency(baseAmount + projectedCorrection)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Usar Base") {
                            finalPaidAmountText = AppFormatters.currency(baseAmount)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Section {
                    Label(
                        "Este ajuste de correção/juros impacta apenas o fechamento mensal do fluxo de caixa e não altera o saldo devedor de quitação do financiamento.",
                        systemImage: "shield.checkered"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                }
            }
            .navigationTitle("Confirmar Pagamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar e Pagar") {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        store.confirmContractInstallmentPayment(
                            transactionId: transaction.id,
                            realPaidAmount: parsedFinalAmount
                        )
                        dismiss()
                    }
                    .bold()
                    .disabled(parsedFinalAmount <= 0)
                }
            }
        }
    }
}

// MARK: - PreferenceKey para detecção de Scroll Down
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
