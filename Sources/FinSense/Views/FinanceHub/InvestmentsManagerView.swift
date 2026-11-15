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
                            date: Date(),
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

    @State private var isMovementSheetPresented: Bool = false
    @State private var movementSheetType: InvestmentMovementType = .deposit
    @State private var movementPendingDeletion: InvestmentMovement? = nil

    public init(store: FinancialDataStore, investmentId: UUID) {
        self.store = store
        self.investmentId = investmentId
    }

    private var currentInvestment: InvestmentItem? {
        store.investments.first(where: { $0.id == investmentId })
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
        let timeline = store.investmentMovementTimeline(for: inv.id)

        let totalDeposits = movements.filter { $0.type == .deposit }.reduce(0.0) { $0 + $1.amount }
        let totalWithdrawals = movements.filter { $0.type == .withdrawal }.reduce(0.0) { $0 + $1.amount }
        let futureProjections = timeline.filter(\.isFuture).reduce(0.0) { $0 + $1.projectedDeposits }

        let linkedQuotaRules = store.categoryQuotas.filter {
            $0.quotaType == .investment && $0.linkedInvestmentId == inv.id
        }

        ScrollView {
            VStack(spacing: 16) {
                // Header Card
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
                        }

                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Saldo Acumulado")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                Text(AppFormatters.currency(inv.balance))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#10B981"))
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
                .padding(.top, 10)

                // Metric Cards Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    LiquidGlassCard(cornerRadius: 14, padding: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Total Aportado")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Image(systemName: "arrow.down.right.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                            Text(AppFormatters.currency(totalDeposits))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#10B981"))
                            Text("\(movements.filter { $0.type == .deposit }.count) aporte(s)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    LiquidGlassCard(cornerRadius: 14, padding: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Total Resgatado")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Image(systemName: "arrow.up.left.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "#EF4444"))
                            }
                            Text(AppFormatters.currency(totalWithdrawals))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#EF4444"))
                            Text("\(movements.filter { $0.type == .withdrawal }.count) resgate(s)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    LiquidGlassCard(cornerRadius: 14, padding: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Projeção Cotas")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "#6366F1"))
                            }
                            Text(AppFormatters.currency(futureProjections))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#6366F1"))
                            Text("Próximos 6 meses")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    LiquidGlassCard(cornerRadius: 14, padding: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Saldo Líquido")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                            Text(AppFormatters.currency(inv.balance))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                            Text("Posição cadastrada")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Gráfico de Barras
                LiquidGlassCard(cornerRadius: 20, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fluxo Mensal & Projeções")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Text("Aportes realizados no passado e projeção de cotas futuras")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }

                        // Legenda
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#10B981")).frame(width: 8, height: 8)
                                Text("Aportes").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#EF4444")).frame(width: 8, height: 8)
                                Text("Resgates").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#6366F1")).frame(width: 8, height: 8)
                                Text("Projeção").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
                            }
                        }

                        let hasData = timeline.contains { $0.deposits > 0 || $0.withdrawals > 0 || $0.projectedDeposits > 0 }

                        if hasData {
                            Chart {
                                ForEach(timeline) { pt in
                                    if pt.deposits > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            y: .value("Valor", pt.deposits)
                                        )
                                        .foregroundStyle(Color(hex: "#10B981"))
                                        .position(by: .value("Tipo", "Aportes"))
                                        .cornerRadius(3)
                                    }

                                    if pt.withdrawals > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            y: .value("Valor", pt.withdrawals)
                                        )
                                        .foregroundStyle(Color(hex: "#EF4444"))
                                        .position(by: .value("Tipo", "Resgates"))
                                        .cornerRadius(3)
                                    }

                                    if pt.projectedDeposits > 0 {
                                        BarMark(
                                            x: .value("Mês", pt.shortLabel),
                                            y: .value("Valor", pt.projectedDeposits)
                                        )
                                        .foregroundStyle(Color(hex: "#6366F1"))
                                        .position(by: .value("Tipo", "Projeção"))
                                        .cornerRadius(3)
                                    }
                                }
                            }
                            .frame(height: 190)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    if let doubleVal = value.as(Double.self) {
                                        AxisValueLabel {
                                            Text(AppFormatters.currency(doubleVal))
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

                // Cotas Vinculadas
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

                // Todas as Movimentações
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
