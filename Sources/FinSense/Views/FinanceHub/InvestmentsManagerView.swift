// Sources/FinSense/Views/FinanceHub/InvestmentsManagerView.swift
import SwiftUI
import Charts

public struct InvestmentsManagerView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var isAddInvestmentPresented: Bool = false
    @State private var activeMovementInvestment: InvestmentItem? = nil
    @State private var selectedInvestmentForDetails: InvestmentItem? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Banner de Patrimônio Investido
                    LiquidGlassCard(cornerRadius: 22, padding: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total em Investimentos")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.secondary)

                                Text(AppFormatters.currency(store.totalInvestedAmount))
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }

                            Spacer()

                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color(hex: "#10B981").opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Lista de Investimentos
                    if store.investments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                            Text("Nenhum investimento cadastrado")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Toque em '+' para cadastrar CDB, Tesouro, Ações ou Cofrinhos.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.investments) { inv in
                                LiquidGlassCard(cornerRadius: 18, padding: 14) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Button {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            selectedInvestmentForDetails = inv
                                        } label: {
                                            HStack {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color(hex: inv.colorHex).opacity(0.18))
                                                        .frame(width: 38, height: 38)
                                                    Image(systemName: inv.iconSymbol)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundStyle(Color(hex: inv.colorHex))
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(inv.name)
                                                        .font(.system(size: 15, weight: .bold))
                                                        .foregroundStyle(Color.primary)
                                                    Text(inv.groupName)
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(Color.secondary)
                                                }

                                                Spacer()

                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(AppFormatters.currency(inv.balance))
                                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                                        .foregroundStyle(Color.primary)
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundStyle(Color.secondary.opacity(0.5))
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        HStack(spacing: 8) {
                                            Button {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                selectedInvestmentForDetails = inv
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "chart.bar.xaxis")
                                                    Text("Ver Detalhes")
                                                }
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.primary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                                            }
                                            .buttonStyle(.plain)

                                            Button {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                activeMovementInvestment = inv
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.up.right.circle.fill")
                                                    Text("Aportar / Resgatar")
                                                }
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#0284C7"))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.12)))
                                            }
                                            .buttonStyle(.plain)

                                            Spacer()

                                            Button {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                store.deleteInvestment(inv.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .navigationTitle("Investimentos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isAddInvestmentPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddInvestmentPresented) {
            InvestmentEditorSheet(store: store)
        }
        .sheet(item: $selectedInvestmentForDetails) { inv in
            InvestmentDetailView(store: store, investmentId: inv.id)
        }
        .sheet(item: $activeMovementInvestment) { inv in
            InvestmentMovementSheet(store: store, investment: inv)
        }
    }
}

public struct InvestmentEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var groupName: String = "Renda Fixa"
    @State private var initialBalanceString: String = ""
    @State private var selectedAccountId: UUID = UUID()
    @State private var colorHex: String = "#10B981"

    public var body: some View {
        NavigationStack {
            Form {
                Section("Dados do Ativo") {
                    TextField("Nome (ex: CDB 110% CDI, Tesouro Selic)", text: $name)
                    TextField("Grupo (ex: Renda Fixa, Ações, Cofrinho)", text: $groupName)

                    HStack {
                        Text("Saldo Atual")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $initialBalanceString)
                    }

                    Picker("Conta de Custódia", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(acc.id)
                        }
                    }
                }
            }
            .navigationTitle("Novo Investimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let bal = AppFormatters.parseAmount(initialBalanceString) ?? 0.0
                        store.createInvestment(
                            name: name,
                            groupName: groupName,
                            investmentAccountId: selectedAccountId,
                            balance: bal,
                            colorHex: colorHex
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let first = store.accounts.first {
                    selectedAccountId = first.id
                }
            }
        }
    }
}

public struct InvestmentMovementSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let investment: InvestmentItem
    public let initialMovementType: InvestmentMovementType
    @Environment(\.dismiss) var dismiss

    @State private var movementType: InvestmentMovementType
    @State private var amountString: String = ""
    @State private var selectedSourceAccountId: UUID = UUID()
    @State private var date: Date = Date()
    @State private var notes: String = ""

    public init(
        store: FinancialDataStore,
        investment: InvestmentItem,
        initialMovementType: InvestmentMovementType = .deposit
    ) {
        self.store = store
        self.investment = investment
        self.initialMovementType = initialMovementType
        _movementType = State(initialValue: initialMovementType)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de Movimentação") {
                    Picker("Tipo", selection: $movementType) {
                        Text("Aporte").tag(InvestmentMovementType.deposit)
                        Text("Resgate").tag(InvestmentMovementType.withdrawal)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Valores") {
                    HStack {
                        Text("Valor")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $amountString)
                    }

                    DatePicker("Data", selection: $date, displayedComponents: [.date])

                    Picker(movementType == .deposit ? "Debitar da Conta" : "Creditar na Conta", selection: $selectedSourceAccountId) {
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(acc.id)
                        }
                    }

                    TextField("Observações (opcional)", text: $notes)
                }
            }
            .navigationTitle("\(movementType.title): \(investment.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        guard let amount = AppFormatters.parseAmount(amountString), amount > 0 else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.recordInvestmentMovement(
                            investmentId: investment.id,
                            type: movementType,
                            amount: amount,
                            sourceAccountId: selectedSourceAccountId,
                            date: date,
                            notes: notes
                        )
                        dismiss()
                    }
                    .disabled(AppFormatters.parseAmount(amountString) == nil)
                }
            }
            .onAppear {
                movementType = initialMovementType
                if let first = store.accounts.first {
                    selectedSourceAccountId = first.id
                }
            }
        }
    }
}

// MARK: - Investment Detail View (iOS Mobile)

public struct InvestmentDetailView: View {
    @ObservedObject var store: FinancialDataStore
    public let investmentId: UUID
    @Environment(\.dismiss) var dismiss

    @State private var selectedYear: Int
    @State private var selectedPeriod: InvestmentPeriodFilter = .oneYear
    @State private var isMovementSheetPresented: Bool = false
    @State private var movementSheetType: InvestmentMovementType = .deposit
    @State private var movementPendingDeletion: InvestmentMovement? = nil

    public init(store: FinancialDataStore, investmentId: UUID, initialYear: Int? = nil) {
        self.store = store
        self.investmentId = investmentId
        let y = initialYear ?? Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: y)
    }

    private var currentInvestment: InvestmentItem? {
        store.investments.first(where: { $0.id == investmentId })
    }

    private var availableYears: [Int] {
        let currentY = store.calendar.component(.year, from: Date())
        let movYears = store.investmentMovements(for: investmentId).map {
            store.calendar.component(.year, from: $0.date)
        }
        let minY = min(currentY - 2, movYears.min() ?? (currentY - 2))
        let maxY = max(currentY + 2, movYears.max() ?? (currentY + 2))
        return Array(minY...maxY)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                if let inv = currentInvestment {
                    detailContent(inv)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.secondary)
                        Text("Investimento não encontrado ou removido.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .navigationTitle(currentInvestment?.name ?? "Detalhes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isMovementSheetPresented) {
                if let inv = currentInvestment {
                    InvestmentMovementSheet(
                        store: store,
                        investment: inv,
                        initialMovementType: movementSheetType
                    )
                }
            }
            .alert(
                "Confirmar Exclusão de Movimentação",
                isPresented: Binding(
                    get: { movementPendingDeletion != nil },
                    set: { if !$0 { movementPendingDeletion = nil } }
                ),
                presenting: movementPendingDeletion
            ) { mov in
                Button("Excluir Movimentação", role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.deleteInvestmentMovement(investmentId: investmentId, movementId: mov.id)
                    movementPendingDeletion = nil
                }
                Button("Cancelar", role: .cancel) {
                    movementPendingDeletion = nil
                }
            } message: { mov in
                Text("Deseja realmente excluir a movimentação de \(mov.type.title) no valor de \(AppFormatters.currency(mov.amount)) de \(AppFormatters.shortDate(mov.date))? O saldo do investimento e o lançamento de conta serão estornados.")
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ inv: InvestmentItem) -> some View {
        let holderAccount = store.account(for: inv.investmentAccountId)
        let movements = store.investmentMovements(for: inv.id)
        let timeline = store.investmentTimeline(for: inv.id, year: selectedYear, period: selectedPeriod)
        let currentYear = store.calendar.component(.year, from: Date())
        let isPastYear = selectedYear < currentYear

        let futureProjections = timeline.filter(\.isFuture).reduce(0.0) { $0 + $1.projectedDeposits }
            + (timeline.first(where: \.isCurrent)?.projectedDeposits ?? 0.0)
        let futureWithdrawals = timeline.filter(\.isFuture).reduce(0.0) { $0 + $1.projectedWithdrawals }
            + (timeline.first(where: \.isCurrent)?.projectedWithdrawals ?? 0.0)
        let forecastEndBalance = timeline.last?.endBalance ?? max(0, inv.balance + futureProjections - futureWithdrawals)

        let targetMonth = timeline.last?.month ?? 12
        let targetYear = timeline.last?.year ?? selectedYear
        let targetMonthLabel = String(format: "%02d/%04d", targetMonth, targetYear)

        let linkedQuotaRules = store.categoryQuotas.filter {
            $0.quotaType == .investment && $0.linkedInvestmentId == inv.id
        }

        ScrollView {
            VStack(spacing: 16) {
                // 1. Barra de Seleção de Ano (no topo)
                HStack(spacing: 6) {
                    Button {
                        if let idx = availableYears.firstIndex(of: selectedYear), idx > 0 {
                            selectedYear = availableYears[idx - 1]
                        } else {
                            selectedYear -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableYears, id: \.self) { y in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedYear = y
                                } label: {
                                    Text(String(y))
                                        .font(.system(size: 13, weight: y == selectedYear ? .bold : .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(y == selectedYear ? Color.accentColor : Color.primary.opacity(0.07))
                                        )
                                        .foregroundStyle(y == selectedYear ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    Button {
                        if let idx = availableYears.firstIndex(of: selectedYear), idx < availableYears.count - 1 {
                            selectedYear = availableYears[idx + 1]
                        } else {
                            selectedYear += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // 2. Card do Ativo (Identificação, Saldo, Toggle Consolidado, Botões de Movimentação)
                LiquidGlassCard(cornerRadius: 20, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: inv.colorHex).opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: inv.iconSymbol)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color(hex: inv.colorHex))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(inv.name)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color.primary)
                                    Text(inv.groupName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color(hex: inv.colorHex).opacity(0.15)))
                                        .foregroundStyle(Color(hex: inv.colorHex))
                                }

                                Text("Conta: \(holderAccount?.name ?? "Não informada")")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondary)
                            }

                            Spacer()

                            Toggle(isOn: Binding(
                                get: { inv.showInConsolidated },
                                set: { _ in store.toggleInvestmentConsolidated(inv.id) }
                            )) {
                                Text("Consolidado")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                            }
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        if !inv.notes.isEmpty {
                            Text(inv.notes)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }

                        Divider()
                            .background(Color.primary.opacity(0.08))

                        HStack(spacing: 10) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                movementSheetType = .deposit
                                isMovementSheetPresented = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.right.circle.fill")
                                    Text("Novo Aporte")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#10B981")))
                            }
                            .buttonStyle(.plain)

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                movementSheetType = .withdrawal
                                isMovementSheetPresented = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.left.circle.fill")
                                    Text("Resgatar")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // 3. Barra de Seleção de Período (3 meses, 6 meses, 1 ano) - Acima dos Cards
                VStack(spacing: 6) {
                    HStack {
                        Text("Período do Planejamento")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondary)

                        Spacer()

                        if isPastYear {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Ano Histórico (\(selectedYear))")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                        }
                    }

                    Picker("Período", selection: $selectedPeriod) {
                        ForEach(InvestmentPeriodFilter.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)

                // 4. Cards de Métricas (Removido total aportado e total resgatado)
                // Cards: Saldo Acumulado, Projeção Futura e Previsão para [12/2026]
                if !isPastYear {
                    LiquidGlassCard(cornerRadius: 16, padding: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Saldo Acumulado")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                            Text(AppFormatters.currency(inv.balance))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#10B981"))
                            Text("Posição cadastrada atual")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        LiquidGlassCard(cornerRadius: 14, padding: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Projeção Futura")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#6366F1"))
                                }
                                Text(AppFormatters.currency(futureProjections - futureWithdrawals))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#6366F1"))
                                Text(futureWithdrawals > 0
                                     ? "Aportes: \(AppFormatters.currency(futureProjections)) | Resgates: \(AppFormatters.currency(futureWithdrawals))"
                                     : "Aportes cotas no período")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                            }
                        }

                        LiquidGlassCard(cornerRadius: 14, padding: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Previsão para \(targetMonthLabel)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#3B82F6"))
                                }
                                Text(AppFormatters.currency(forecastEndBalance))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#3B82F6"))
                                Text("Saldo estimado no fim")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    let openingBal = timeline.first?.baseAccumulated ?? 0.0
                    let yearDeposits = timeline.reduce(0.0) { $0 + $1.deposits }
                    let closingBal = timeline.last?.endBalance ?? 0.0

                    LiquidGlassCard(cornerRadius: 16, padding: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Saldo Inicial (\(selectedYear))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "#3B82F6"))
                            }
                            Text(AppFormatters.currency(openingBal))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#3B82F6"))
                            Text("Posição em 01/01/\(selectedYear)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        LiquidGlassCard(cornerRadius: 14, padding: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Aportes em \(selectedYear)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Image(systemName: "arrow.down.right.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#10B981"))
                                }
                                Text(AppFormatters.currency(yearDeposits))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#10B981"))
                                Text("Histórico do exercício")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                            }
                        }

                        LiquidGlassCard(cornerRadius: 14, padding: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Fechamento (\(selectedYear))")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Image(systemName: "flag.checkered")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                }
                                Text(AppFormatters.currency(closingBal))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                Text("Posição em 31/12/\(selectedYear)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // 5. Gráfico de Barras: Acumulado, Aportes, Projeção e Resgates
                LiquidGlassCard(cornerRadius: 20, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fluxo Mensal & Composição Acumulada")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Text(isPastYear
                                 ? "Evolução histórica mês a mês em \(selectedYear)"
                                 : "Evolução do acumulado com aportes e projeções na mesma barra")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }

                        // Legenda: Aportes, Projeção, Resgate, Acumulado
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#10B981")).frame(width: 8, height: 8)
                                Text("Aportes").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
                            }
                            if !isPastYear {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hex: "#6366F1")).frame(width: 8, height: 8)
                                    Text("Projeção").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
                                }
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#EF4444")).frame(width: 8, height: 8)
                                Text("Resgate").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#3B82F6")).frame(width: 8, height: 8)
                                Text("Acumulado").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
                            }
                        }

                        let hasData = timeline.contains {
                            $0.baseAccumulated > 0 || $0.deposits > 0 || $0.withdrawals > 0 || $0.projectedDeposits > 0 || $0.projectedWithdrawals > 0
                        }

                        if hasData {
                            Chart {
                                ForEach(timeline) { pt in
                                    // 1. Acumulado (Base da barra)
                                    if pt.baseAccumulated > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            yStart: .value("Base", 0),
                                            yEnd: .value("Valor", pt.baseAccumulated)
                                        )
                                        .foregroundStyle(Color(hex: "#3B82F6"))
                                        .position(by: .value("Grupo", "Evolução"))
                                        .cornerRadius(pt.deposits > 0 || pt.projectedDeposits > 0 ? 0 : 3)
                                    }

                                    // 2. Aportes (Fatia sobre o acumulado)
                                    if pt.deposits > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            yStart: .value("Base", pt.baseAccumulated),
                                            yEnd: .value("Valor", pt.baseAccumulated + pt.deposits)
                                        )
                                        .foregroundStyle(Color(hex: "#10B981"))
                                        .position(by: .value("Grupo", "Evolução"))
                                        .cornerRadius(pt.projectedDeposits > 0 ? 0 : 3)
                                    }

                                    // 3. Projeção (Fatia sobre acumulado + aportes)
                                    if pt.projectedDeposits > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            yStart: .value("Base", pt.baseAccumulated + pt.deposits),
                                            yEnd: .value("Valor", pt.baseAccumulated + pt.deposits + pt.projectedDeposits)
                                        )
                                        .foregroundStyle(Color(hex: "#6366F1"))
                                        .position(by: .value("Grupo", "Evolução"))
                                        .cornerRadius(3)
                                    }

                                    // 4. Resgates Realizados (Barra ao lado se houver resgate no mês)
                                    if pt.withdrawals > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            yStart: .value("Base", 0),
                                            yEnd: .value("Valor", pt.withdrawals)
                                        )
                                        .foregroundStyle(Color(hex: "#EF4444"))
                                        .position(by: .value("Grupo", "Resgates"))
                                        .cornerRadius(3)
                                    }

                                    // 5. Resgates Previstos Futuros
                                    if pt.projectedWithdrawals > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            yStart: .value("Base", 0),
                                            yEnd: .value("Valor", pt.projectedWithdrawals)
                                        )
                                        .foregroundStyle(Color(hex: "#EF4444").opacity(0.65))
                                        .position(by: .value("Grupo", "Resgates"))
                                        .cornerRadius(3)
                                    }
                                }
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    if let doubleVal = value.as(Double.self) {
                                        AxisValueLabel {
                                            Text(AppFormatters.compactCurrency(doubleVal))
                                                .font(.system(size: 9, design: .monospaced))
                                        }
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                Text("Nenhuma movimentação ou projeção neste período")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 140)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // 6. Cotas Vinculadas
                if !linkedQuotaRules.isEmpty {
                    LiquidGlassCard(cornerRadius: 18, padding: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Cotas de Investimento Vinculadas", systemImage: "target")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(linkedQuotaRules.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.secondary)
                            }

                            ForEach(linkedQuotaRules) { rule in
                                HStack {
                                    ZStack {
                                        Circle().fill(Color(hex: "#6366F1").opacity(0.18)).frame(width: 30, height: 30)
                                        Image(systemName: rule.iconSymbol)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color(hex: "#6366F1"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rule.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                        Text("\(rule.plannedQuantity) un. × \(AppFormatters.currency(rule.estimatedUnitPrice)) = \(AppFormatters.currency(Double(rule.plannedQuantity) * rule.estimatedUnitPrice)) / mês")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.secondary)
                                    }

                                    Spacer()

                                    Text(rule.repeatForFutureMonths ? "Recorrente" : "Mês atual")
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // 7. Todas as Movimentações
                LiquidGlassCard(cornerRadius: 20, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Todas as Movimentações", systemImage: "clock.arrow.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Text("\(movements.count) registros")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }

                        if movements.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                Text("Nenhuma movimentação registrada")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondary)
                                Button {
                                    movementSheetType = .deposit
                                    isMovementSheetPresented = true
                                } label: {
                                    Text("Fazer Primeiro Aporte")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#10B981"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color(hex: "#10B981").opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(movements) { mov in
                                    let srcAccount = store.account(for: mov.sourceAccountId)
                                    let dstAccount = store.account(for: mov.investmentAccountId)

                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill((mov.type == .deposit ? Color(hex: "#10B981") : Color(hex: "#EF4444")).opacity(0.15))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: mov.type == .deposit ? "arrow.down.right" : "arrow.up.left")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(mov.type == .deposit ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(mov.type.title)
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Color.primary)
                                                Text("• " + AppFormatters.shortDate(mov.date))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.secondary)
                                            }

                                            Text(mov.type == .deposit
                                                 ? "De \(srcAccount?.name ?? "Conta") → \(dstAccount?.name ?? "Investimento")"
                                                 : "De \(dstAccount?.name ?? "Investimento") → \(srcAccount?.name ?? "Conta")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.secondary)

                                            if !mov.notes.isEmpty {
                                                Text(mov.notes)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.secondary.opacity(0.8))
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        Text((mov.type == .deposit ? "+ " : "- ") + AppFormatters.currency(mov.amount))
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(mov.type == .deposit ? Color(hex: "#10B981") : Color(hex: "#EF4444"))

                                        Button {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            movementPendingDeletion = mov
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)

                                    if mov.id != movements.last?.id {
                                        Divider().background(Color.primary.opacity(0.06))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}
