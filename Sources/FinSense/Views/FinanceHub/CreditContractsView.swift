// Sources/FinSense/Views/FinanceHub/CreditContractsView.swift
import SwiftUI

public struct CreditContractsView: View {
    @ObservedObject var store: FinancialDataStore
    public let kind: CreditContractKind?
    @State private var isAddContractPresented: Bool = false
    @State private var simulatingContract: CreditContract? = nil
    @State private var settlingContract: CreditContract? = nil
    @State private var contractPendingDeletion: CreditContract? = nil

    public init(store: FinancialDataStore, kind: CreditContractKind? = nil) {
        self.store = store
        self.kind = kind
    }

    private var displayedContracts: [CreditContract] {
        if let kind {
            return store.contracts.filter { $0.kind == kind }
        }
        return store.contracts
    }

    private var viewTitle: String {
        switch kind {
        case .loan: return "Empréstimos"
        case .financing: return "Financiamentos"
        case nil: return "Financiamentos & Empréstimos"
        }
    }

    private var emptyIcon: String {
        kind == .loan ? "banknote.fill" : "house.and.flag.fill"
    }

    private var emptyTitle: String {
        switch kind {
        case .loan: return "Nenhum empréstimo cadastrado"
        case .financing: return "Nenhum financiamento cadastrado"
        case nil: return "Nenhum contrato cadastrado"
        }
    }

    private var emptySubtitle: String {
        switch kind {
        case .loan: return "Cadastre seu empréstimo consignado, pessoal ou outros."
        case .financing: return "Cadastre seu financiamento imobiliário ou veicular."
        case nil: return "Cadastre seu financiamento imobiliário, veicular ou consignado."
        }
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if displayedContracts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: emptyIcon)
                                .font(.system(size: 38))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                            Text(emptyTitle)
                                .font(.system(size: 15, weight: .bold))
                            Text(emptySubtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(displayedContracts) { contract in
                                contractCard(contract)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle(viewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isAddContractPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddContractPresented) {
            ContractEditorSheet(store: store, initialKind: kind ?? .financing)
        }
        .sheet(item: $simulatingContract) { contract in
            AmortizationSimulatorSheet(store: store, contract: contract)
        }
        .sheet(item: $settlingContract) { contract in
            SettleContractSheet(store: store, contract: contract)
        }
        .alert(
            "Excluir Contrato",
            isPresented: Binding(
                get: { contractPendingDeletion != nil },
                set: { if !$0 { contractPendingDeletion = nil } }
            ),
            presenting: contractPendingDeletion
        ) { contract in
            Button("Excluir", role: .destructive) {
                store.deleteContract(contract.id)
                contractPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) {
                contractPendingDeletion = nil
            }
        } message: { contract in
            Text("Deseja realmente excluir o contrato \"\(contract.name)\"? Todas as parcelas futuras serão removidas e transações vinculadas serão desfeitas.")
        }
    }

    @ViewBuilder
    private func contractCard(_ contract: CreditContract) -> some View {
        let metrics = store.progressMetrics(for: contract)
        let hasExtraAmortization = metrics.eliminatedByAmortizationCount > 0 || contract.extraAmortizedTotal > 0.01
        let paidCount = metrics.paidInFlowCount
        let remainingCount = metrics.remainingCount
        let outstandingBalance = store.currentOutstandingBalance(for: contract)
        let nominalRemaining = store.remainingNominalAmount(for: contract)
        let projectedPayoff = store.projectedPayoffAmount(for: contract)
        let discountEstimate = max(nominalRemaining - projectedPayoff, 0)
        let accentHex = contract.kind == .loan ? "#D97706" : "#8B5CF6"

        LiquidGlassCard(cornerRadius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                // Header do Card
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: accentHex).opacity(0.18))
                            .frame(width: 42, height: 42)
                        Image(systemName: contract.iconSymbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: accentHex))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(contract.name)
                                .font(.system(size: 15, weight: .bold))
                                .lineLimit(1)

                            Text(contract.subtypeDisplayName)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(Color(hex: accentHex).opacity(0.18)))
                                .foregroundStyle(Color(hex: accentHex))

                            if contract.isSettled {
                                Text("QUITADO")
                                    .font(.system(size: 9, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color(hex: "#10B981").opacity(0.2)))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                        }

                        HStack(spacing: 6) {
                            Text("\(contract.amortizationSystem.rawValue) • Dia \(contract.billingDay)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)

                            if contract.kind == .loan && (contract.loanSubtype == .consignado || contract.effectiveLoanModel?.isPayrollDeductible == true) {
                                Text("• Débito em Folha")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                        }
                    }

                    Spacer()

                    Button {
                        contractPendingDeletion = contract
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                Divider().opacity(0.4)

                // Grid de Detalhes
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    metricItem(label: "Saldo Devedor", value: AppFormatters.currency(outstandingBalance), color: Color(hex: "#EF4444"))
                    metricItem(label: "Parcela Devida", value: AppFormatters.currency(contract.installmentAmount), color: .primary)
                    metricItem(
                        label: "Taxa de Juros",
                        value: String(format: "%.2f%% a.m.", contract.monthlyInterestRate),
                        color: .primary
                    )

                    if contract.kind == .financing {
                        metricItem(label: "Parcela Base", value: AppFormatters.currency(contract.effectiveBaseInstallmentPrice), color: .secondary)
                        metricItem(label: "Seguros/Taxas", value: AppFormatters.currency(contract.effectiveInsuranceFee + contract.effectiveAdminFee), color: .secondary)
                        metricItem(label: "Indexador", value: contract.indexationRate?.rawValue ?? "TR", color: .secondary)
                    } else {
                        metricItem(label: "Total Contratado", value: AppFormatters.currency(contract.totalContractedAmount), color: .secondary)
                        metricItem(label: "Soma Nominal", value: AppFormatters.currency(nominalRemaining), color: .secondary)
                        metricItem(label: "Economia Quitação", value: AppFormatters.currency(discountEstimate), color: Color(hex: "#10B981"))
                    }
                }

                // Duality de Prazos & Avanço
                if hasExtraAmortization {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Original: \(metrics.originalMonthsFormatted)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                            Text("Novo: \(metrics.newRecalculatedMonthsFormatted)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#10B981"))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("⚡ \(metrics.savedTimeString) poupados")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Color(hex: "#10B981"))
                            Text("\(metrics.eliminatedByAmortizationCount) parcelas eliminadas")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#10B981").opacity(0.08)))
                }

                // Barra de Progresso Segmentada
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(hasExtraAmortization
                             ? "\(metrics.totalOvercomeMonths) de \(metrics.originalTotalInstallments) meses superados"
                             : "\(paidCount) de \(contract.totalInstallments) parcelas pagas")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text(String(format: "%.0f%%", metrics.globalCompletionPercentage * 100))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: accentHex))
                    }

                    SegmentedContractProgressBar(metrics: metrics, accentHex: accentHex)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: accentHex)).frame(width: 6, height: 6)
                            Text("\(paidCount) pagas")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }

                        if hasExtraAmortization {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#10B981")).frame(width: 6, height: 6)
                                Text("\(metrics.eliminatedByAmortizationCount) amortizadas")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                            }
                        }

                        HStack(spacing: 4) {
                            Circle().fill(Color.primary.opacity(0.3)).frame(width: 6, height: 6)
                            Text("\(remainingCount) restantes")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                    }
                }

                // Projeção para Quitar Hoje (Box Destacada)
                if contract.isSettled {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(hex: "#10B981"))
                        Text("Contrato Totalmente Liquidado")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#10B981"))
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#10B981").opacity(0.12)))
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#10B981"))
                                Text("Valor para Quitar Hoje:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                            }
                            Text("Economia de juros: \(AppFormatters.currency(discountEstimate))")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#10B981"))
                        }

                        Spacer()

                        Text(AppFormatters.currency(contract.kind == .loan ? outstandingBalance : projectedPayoff))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#10B981").opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#10B981").opacity(0.25), lineWidth: 1))
                }

                // Botões de Ação: Amortizar e Quitar
                if !contract.isSettled {
                    HStack(spacing: 10) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            simulatingContract = contract
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.forward.and.arrow.up.backward.circle.fill")
                                Text("Amortizar")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#0284C7"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.14)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            settlingContract = contract
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Quitar Contrato")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "#10B981")))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

// MARK: - Segmented Contract Progress Bar

public struct SegmentedContractProgressBar: View {
    public let metrics: ContractProgressMetrics
    public let accentHex: String

    public init(metrics: ContractProgressMetrics, accentHex: String) {
        self.metrics = metrics
        self.accentHex = accentHex
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let naturalRatio = CGFloat(min(max(metrics.naturalProgressRatio, 0.0), 1.0))
            let amortRatio = CGFloat(min(max(metrics.amortizationAccelerationRatio, 0.0), 1.0))

            let naturalWidth = totalWidth * naturalRatio
            let amortWidth = min(totalWidth * amortRatio, max(0, totalWidth - naturalWidth))

            ZStack(alignment: .leading) {
                // Trilho de fundo
                Capsule()
                    .fill(Color.primary.opacity(0.12))

                HStack(spacing: 0) {
                    // Segmento 1: Pagas no fluxo
                    if naturalWidth > 0.001 {
                        Rectangle()
                            .fill(Color(hex: accentHex))
                            .frame(width: naturalWidth)
                    }

                    // Segmento 2: Amortização extraordinária
                    if metrics.eliminatedByAmortizationCount > 0 && amortWidth > 0.001 {
                        Rectangle()
                            .fill(Color(hex: "#10B981"))
                            .frame(width: amortWidth)
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Settle Contract Sheet

public struct SettleContractSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let contract: CreditContract
    @Environment(\.dismiss) var dismiss

    @State private var finalPayoffAmountText: String = ""
    @State private var selectedAccountId: UUID = UUID()
    @State private var settleDate: Date = Date()
    @State private var isConfirming: Bool = false
    @State private var errorMessage: String? = nil

    public init(store: FinancialDataStore, contract: CreditContract) {
        self.store = store
        self.contract = contract
    }

    public var body: some View {
        NavigationStack {
            let outstandingBalance = store.currentOutstandingBalance(for: contract)
            let nominalRemaining = store.remainingNominalAmount(for: contract)
            let projectedPayoff = store.projectedPayoffAmount(for: contract)

            Form {
                Section("Valores de Referência") {
                    HStack {
                        Text("Saldo Devedor Atual")
                        Spacer()
                        Text(AppFormatters.currency(outstandingBalance))
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .foregroundStyle(Color(hex: "#EF4444"))
                    }

                    HStack {
                        Text("Soma Nominal Restante")
                        Spacer()
                        Text(AppFormatters.currency(nominalRemaining))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                    }

                    HStack {
                        Text("Projeção para Quitar Hoje")
                        Spacer()
                        Text(AppFormatters.currency(projectedPayoff))
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                }

                Section("Pagamento da Quitação") {
                    HStack {
                        Text("Valor Final")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $finalPayoffAmountText)
                    }

                    HStack(spacing: 8) {
                        Button("Usar Saldo Devedor") {
                            finalPayoffAmountText = AppFormatters.currency(outstandingBalance)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Usar Projeção") {
                            finalPayoffAmountText = AppFormatters.currency(projectedPayoff)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Picker("Conta de Débito", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            let bal = store.currentBalance(forAccount: acc.id)
                            Text("\(acc.name) (\(AppFormatters.currency(bal)))").tag(acc.id)
                        }
                    }

                    DatePicker("Data da Quitação", selection: $settleDate, displayedComponents: [.date])
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Quitar \(contract.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        guard let finalVal = AppFormatters.parseAmount(finalPayoffAmountText), finalVal > 0 else {
                            errorMessage = "Informe um valor final válido para quitação."
                            return
                        }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        store.settleContract(
                            contractId: contract.id,
                            finalPayoffAmount: finalVal,
                            accountId: selectedAccountId,
                            date: settleDate
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                selectedAccountId = contract.accountId
                let suggested = (outstandingBalance > 0.01) ? outstandingBalance : (projectedPayoff > 0.01 ? projectedPayoff : nominalRemaining)
                finalPayoffAmountText = AppFormatters.currency(suggested)
            }
        }
    }
}

// MARK: - Contract Editor Sheet

public struct ContractEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    @Environment(\.dismiss) var dismiss

    @State private var kind: CreditContractKind
    @State private var name: String = ""
    @State private var totalAmountString: String = ""
    @State private var installmentAmountString: String = ""
    @State private var totalInstallments: Int = 360
    @State private var interestRateString: String = "0,85"
    @State private var billingDay: Int = 10
    @State private var amortizationSystem: AmortizationSystem = .sac
    @State private var selectedAccountId: UUID = UUID()
    @State private var selectedCategoryId: UUID = UUID()

    public init(store: FinancialDataStore, initialKind: CreditContractKind = .financing) {
        self.store = store
        _kind = State(initialValue: initialKind)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de Contrato") {
                    Picker("Tipo", selection: $kind) {
                        Text("Financiamento").tag(CreditContractKind.financing)
                        Text("Empréstimo").tag(CreditContractKind.loan)
                    }
                    .pickerStyle(.segmented)

                    TextField("Identificação (ex: Imóvel CAIXA, Financiamento Carro)", text: $name)

                    Picker("Sistema de Amortização", selection: $amortizationSystem) {
                        Text("SAC (Parcelas decrescentes)").tag(AmortizationSystem.sac)
                        Text("PRICE (Parcelas fixas)").tag(AmortizationSystem.price)
                    }
                }

                Section("Condições Financeiras") {
                    HStack {
                        Text("Saldo Financiado")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $totalAmountString)
                    }

                    HStack {
                        Text("Valor da Parcela")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $installmentAmountString)
                    }

                    Stepper("Prazo: \(totalInstallments) parcelas", value: $totalInstallments, in: 6...420)

                    HStack {
                        Text("Taxa de Juros Mensal (% a.m.)")
                        Spacer()
                        TextField("0,85", text: $interestRateString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Stepper("Dia do Vencimento: \(billingDay)", value: $billingDay, in: 1...31)
                }

                Section("Conta de Débito Automático") {
                    Picker("Conta Bancária", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(acc.id)
                        }
                    }
                }
            }
            .navigationTitle("Novo Contrato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let total = AppFormatters.parseAmount(totalAmountString) ?? 0.0
                        let inst = AppFormatters.parseAmount(installmentAmountString) ?? 0.0
                        let rate = AppFormatters.parseAmount(interestRateString) ?? 0.0

                        store.createContract(
                            kind: kind,
                            name: name,
                            loanSubtype: kind == .loan ? .consignado : nil,
                            financingSubtype: kind == .financing ? .imovel : nil,
                            amortizationSystem: amortizationSystem,
                            totalContractedAmount: total,
                            installmentAmount: inst,
                            billingDay: billingDay,
                            totalInstallments: totalInstallments,
                            monthlyInterestRate: rate,
                            accountId: selectedAccountId,
                            categoryId: store.categories.first?.id ?? UUID()
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
                if let firstCat = store.categories.first(where: { $0.type == .expense }) {
                    selectedCategoryId = firstCat.id
                }
            }
        }
    }
}

// MARK: - Amortization Simulator Sheet

public struct AmortizationSimulatorSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let contract: CreditContract
    @Environment(\.dismiss) var dismiss

    @State private var amortizeAmountString: String = AppFormatters.currency(5000.0)
    @State private var mode: AmortizationRecalculationMode = .reduceTerm
    @State private var selectedAccountId: UUID = UUID()
    @State private var isConfirmingRealAmortization: Bool = false

    public init(store: FinancialDataStore, contract: CreditContract) {
        self.store = store
        self.contract = contract
    }

    public var body: some View {
        NavigationStack {
            let currentBalance = store.currentOutstandingBalance(for: contract)
            let amortizeVal = AppFormatters.parseAmount(amortizeAmountString) ?? 0.0
            let newBalance = max(0, currentBalance - amortizeVal)

            let monthlyRate = (contract.monthlyInterestRate / 100.0)
            let remainingInstallments = max(1, store.remainingInstallmentsCount(for: contract))

            // Estimativas determinísticas matemáticas
            let (newInstallment, newTerm, estimatedSavings): (Double, Int, Double) = {
                guard amortizeVal > 0 else { return (contract.installmentAmount, remainingInstallments, 0.0) }

                if mode == .reduceTerm {
                    if monthlyRate > 0 && contract.installmentAmount > 0 {
                        let inner = contract.installmentAmount - (newBalance * monthlyRate)
                        if inner > 0 {
                            let calcN = log(contract.installmentAmount / inner) / log(1.0 + monthlyRate)
                            let newMonths = max(1, Int(calcN.rounded(.up)))
                            let savedMonths = max(0, remainingInstallments - newMonths)
                            let savings = Double(savedMonths) * contract.installmentAmount - amortizeVal
                            return (contract.installmentAmount, newMonths, max(0, savings))
                        }
                    }
                    let savedMonths = Int((amortizeVal / max(1, contract.installmentAmount)).rounded())
                    return (contract.installmentAmount, max(1, remainingInstallments - savedMonths), Double(savedMonths) * contract.installmentAmount * 0.4)
                } else {
                    let n = Double(remainingInstallments)
                    let newInst: Double = {
                        if monthlyRate > 0 {
                            return (newBalance * monthlyRate * pow(1.0 + monthlyRate, n)) / (pow(1.0 + monthlyRate, n) - 1.0)
                        } else {
                            return newBalance / n
                        }
                    }()
                    let diffPerMonth = max(0, contract.installmentAmount - newInst)
                    let totalSavings = (diffPerMonth * n) - amortizeVal
                    return (newInst, remainingInstallments, max(0, totalSavings))
                }
            }()

            Form {
                Section("Simulação de Aporte Extraordinário") {
                    HStack {
                        Text("Valor a Amortizar")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $amortizeAmountString)
                    }

                    Picker("Estratégia", selection: $mode) {
                        Text("Reduzir Prazo (Meses)").tag(AmortizationRecalculationMode.reduceTerm)
                        Text("Reduzir Parcela (R$)").tag(AmortizationRecalculationMode.reduceInstallment)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Impacto e Economia Projetada") {
                    HStack {
                        Text("Novo Saldo Devedor")
                        Spacer()
                        Text(AppFormatters.currency(newBalance))
                            .font(.system(.body, design: .monospaced))
                            .bold()
                    }

                    if mode == .reduceTerm {
                        HStack {
                            Text("Novo Prazo Estimado")
                            Spacer()
                            Text("\(newTerm) parcelas")
                                .bold()
                                .foregroundStyle(Color(hex: "#10B981"))
                        }
                        HStack {
                            Text("Parcelas Eliminadas")
                            Spacer()
                            Text("\(max(0, remainingInstallments - newTerm)) parcelas a menos")
                                .foregroundStyle(Color(hex: "#10B981"))
                        }
                    } else {
                        HStack {
                            Text("Nova Parcela Estimada")
                            Spacer()
                            Text(AppFormatters.currency(newInstallment))
                                .bold()
                                .foregroundStyle(Color(hex: "#10B981"))
                        }
                    }

                    HStack {
                        Text("Economia Total em Juros")
                        Spacer()
                        Text(AppFormatters.currency(estimatedSavings))
                            .bold()
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                }

                Section("Efetivação Real (Debitar de Conta)") {
                    Picker("Conta de Débito", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            let bal = store.currentBalance(forAccount: acc.id)
                            Text("\(acc.name) (\(AppFormatters.currency(bal)))").tag(acc.id)
                        }
                    }

                    Button {
                        isConfirmingRealAmortization = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Efetivar Amortização Agora")
                                .bold()
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(hex: "#0284C7"))
                }
            }
            .navigationTitle("Amortização")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .alert("Confirmar Amortização", isPresented: $isConfirmingRealAmortization) {
                Button("Cancelar", role: .cancel) {}
                Button("Sim, Efetivar") {
                    if let val = AppFormatters.parseAmount(amortizeAmountString), val > 0 {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        store.amortizeContract(
                            contractId: contract.id,
                            amountPaid: val,
                            accountId: selectedAccountId,
                            date: Date(),
                            mode: mode
                        )
                        dismiss()
                    }
                }
            } message: {
                Text("Será gerada uma despesa de \(AppFormatters.currency(amortizeVal)) na conta selecionada e o saldo devedor do contrato será recalculado imediatamente.")
            }
            .onAppear {
                if let first = store.accounts.first {
                    selectedAccountId = first.id
                }
            }
        }
    }
}
