// Sources/FinSense/Views/FinanceHub/CreditContractsView.swift
import SwiftUI
import UniformTypeIdentifiers

public struct CreditContractsView: View {
    @ObservedObject var store: FinancialDataStore
    public let kind: CreditContractKind?
    @State private var isAddContractPresented: Bool = false
    @State private var isImportDocumentPresented: Bool = false
    @State private var planningContract: CreditContract? = nil
    @State private var simulatingContract: CreditContract? = nil
    @State private var settlingContract: CreditContract? = nil
    @State private var contractPendingDeletion: CreditContract? = nil
    @State private var reschedulingExpiredItem: (contractId: UUID, item: PlannedAmortization)? = nil
    @State private var rescheduleTargetDate: Date = Date()

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
            ToolbarItemGroup(placement: .confirmationAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isImportDocumentPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.viewfinder.fill")
                        Text("Importar PDF")
                            .font(.system(size: 12, weight: .bold))
                    }
                }

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
        .sheet(isPresented: $isImportDocumentPresented) {
            ImportCreditContractDocumentSheet(store: store, defaultKind: kind)
        }
        .sheet(item: $planningContract) { contract in
            AmortizationPlannerSheet(store: store, contract: contract)
        }
        .sheet(item: $simulatingContract) { contract in
            AmortizationSimulatorSheet(store: store, contract: contract)
        }
        .sheet(item: $settlingContract) { contract in
            SettleContractSheet(store: store, contract: contract)
        }
        .sheet(
            isPresented: Binding(
                get: { reschedulingExpiredItem != nil },
                set: { if !$0 { reschedulingExpiredItem = nil } }
            )
        ) {
            if let entry = reschedulingExpiredItem {
                NavigationStack {
                    Form {
                        Section("Reagendar Amortização Planejada") {
                            HStack {
                                Text("Valor Planejado")
                                Spacer()
                                Text(AppFormatters.currency(entry.item.amountDouble))
                                    .bold()
                            }
                            DatePicker("Nova Data", selection: $rescheduleTargetDate, in: Date()..., displayedComponents: [.date])
                        }
                    }
                    .navigationTitle("Reagendar Aporte")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { reschedulingExpiredItem = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salvar") {
                                store.rescheduleExpiredAmortization(
                                    contractId: entry.contractId,
                                    itemId: entry.item.id,
                                    newDate: rescheduleTargetDate
                                )
                                reschedulingExpiredItem = nil
                            }
                            .bold()
                        }
                    }
                }
                .presentationDetents([.medium])
            }
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
                            if contract.effectiveBankDueDay != contract.billingDay {
                                Text("\(contract.amortizationSystem.rawValue) • Cobrança Salário: Dia \(contract.billingDay) • Venc. Banco: Dia \(contract.effectiveBankDueDay)")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Color.secondary)
                            } else {
                                Text("\(contract.amortizationSystem.rawValue) • Dia \(contract.billingDay)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }

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
                        if let growth = contract.averageMonthlyInstallmentGrowth, growth > 0.0001 {
                            metricItem(
                                label: "Projeção Correção",
                                value: "+\(AppFormatters.currency(growth))/mês",
                                color: Color(hex: "#F59E0B")
                            )
                        } else {
                            metricItem(label: "Indexador", value: contract.indexationRate?.rawValue ?? "TR", color: .secondary)
                        }
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

                // Banner de Resolução Assistida para Amortizações Planejadas Vencidas
                let expiredItems = store.expiredPlannedAmortizations(for: contract.id)
                if !expiredItems.isEmpty {
                    ForEach(expiredItems) { expiredItem in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                Text("Amortização Planejada Vencida em \(AppFormatters.shortDate(expiredItem.date)): \(AppFormatters.currency(expiredItem.amountDouble))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                            }

                            HStack(spacing: 8) {
                                Button {
                                    store.confirmPlannedAmortizationPayment(
                                        contractId: contract.id,
                                        itemId: expiredItem.id
                                    )
                                } label: {
                                    Text("Confirmar que paguei")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color(hex: "#10B981")))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    rescheduleTargetDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                                    reschedulingExpiredItem = (contractId: contract.id, item: expiredItem)
                                } label: {
                                    Text("Reagendar data")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color(hex: "#0284C7"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.15)))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.removePlannedAmortization(
                                        contractId: contract.id,
                                        itemId: expiredItem.id
                                    )
                                } label: {
                                    Text("Descartar")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color(hex: "#EF4444"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color(hex: "#EF4444").opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#F59E0B").opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#F59E0B").opacity(0.35), lineWidth: 1))
                    }
                }

                // Resumo do Planejamento de Amortização Salvo (se houver)
                let hasSavedPlan = store.hasSavedAmortizationPlan(for: contract.id)
                if hasSavedPlan, let proj = store.loanProjection(for: contract.id) {
                    let isFullPayoff = proj.doesPlanAchieveFullPayoff && proj.monthsSaved > 0
                    HStack(spacing: 10) {
                        Image(systemName: isFullPayoff ? "checkmark.seal.fill" : "sparkles.rectangle.stack.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: isFullPayoff ? "#10B981" : "#8B5CF6"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isFullPayoff ? "Plano Ativo: Quitação Total Projetada" : "Plano de Amortização Ativo")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(Color(hex: isFullPayoff ? "#10B981" : "#8B5CF6"))

                            Text("\(proj.monthsSaved) parcelas eliminadas • Economia: \(AppFormatters.currency(NSDecimalNumber(decimal: proj.totalInterestSaved).doubleValue))")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: isFullPayoff ? "#10B981" : "#8B5CF6").opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: isFullPayoff ? "#10B981" : "#8B5CF6").opacity(0.3), lineWidth: 1))
                }

                // Botões de Ação: Planejar/Ver Planejamento, Amortizar Manual e Quitar
                if !contract.isSettled {
                    VStack(spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            planningContract = contract
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: hasSavedPlan ? "doc.text.magnifyingglass" : "wand.and.stars")
                                Text(hasSavedPlan ? "Ver Planejamento" : "Planejar Amortização")
                            }
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color(hex: hasSavedPlan ? "#7C3AED" : "#8B5CF6")))
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 10) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                simulatingContract = contract
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "bolt.circle.fill")
                                    Text("Amortizar Agora")
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

// MARK: - Importação de Documento Oficial (Santander DDC & Caixa Evolução Habitação)

public struct ImportCreditContractDocumentSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let defaultKind: CreditContractKind?
    @Environment(\.dismiss) var dismiss

    @State private var rawDocumentText: String = ""
    @State private var parsedDocument: ParsedCreditContractDocument? = nil
    @State private var customContractName: String = ""
    @State private var manualSalaryBillingDay: Int = 1
    @State private var selectedAccountId: UUID = UUID()
    @State private var selectedCategoryId: UUID = UUID()
    @State private var isFileImporterPresented: Bool = false
    @State private var importErrorMessage: String? = nil

    public init(store: FinancialDataStore, defaultKind: CreditContractKind? = nil) {
        self.store = store
        self.defaultKind = defaultKind
    }

    private var salaryPreview: (
        paidCount: Int,
        remainingCount: Int,
        firstFutureBillingDate: Date,
        remainingBalance: Double,
        nextInstallmentAmount: Double
    )? {
        parsedDocument?.recalculatedForSalaryBillingDay(manualSalaryBillingDay, referenceNow: store.effectiveCurrentDate)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("1. Selecionar Documento ou Modelo Oficial") {
                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Selecionar PDF ou Texto do Contrato...", systemImage: "doc.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                    }

                    HStack(spacing: 8) {
                        Button("Carregar DDC Santander") {
                            rawDocumentText = SampleContractDocumentsData.santanderLoanOCRText
                            parseCurrentText(expectedKind: .loan)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Carregar Evolução Caixa") {
                            rawDocumentText = SampleContractDocumentsData.caixaFinancingOCRText
                            parseCurrentText(expectedKind: .financing)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    DisclosureGroup("Colar ou Editar Texto Extraído") {
                        TextEditor(text: $rawDocumentText)
                            .frame(minHeight: 100)
                            .font(.system(size: 11, design: .monospaced))
                        Button("Processar Texto") {
                            parseCurrentText(expectedKind: defaultKind ?? .financing)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if let importErrorMessage {
                    Section {
                        Text(importErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let doc = parsedDocument, let preview = salaryPreview {
                    Section("2. Dia de Cobrança no Salário vs Vencimento no Banco") {
                        Stepper("Dia de Cobrança (Salário/Conta): Dia \(manualSalaryBillingDay)", value: $manualSalaryBillingDay, in: 1...31)
                            .font(.system(size: 13, weight: .bold))

                        HStack {
                            Text("Dia de Recebimento no Banco (PDF)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Dia \(doc.bankDueDay)")
                                .font(.caption.bold())
                                .foregroundStyle(Color(hex: "#0284C7"))
                        }

                        Text("O número de parcelas já pagas (\(preview.paidCount) de \(doc.totalInstallments)) é calculado automaticamente com base no dia em que o valor sai do seu salário (Dia \(manualSalaryBillingDay)).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Section("3. Dados Extraídos do Contrato") {
                        TextField("Nome do Contrato", text: $customContractName)

                        HStack {
                            Text("Instituição / Tipo")
                            Spacer()
                            Text("\(doc.institutionName) • \(doc.kind.rawValue)")
                                .font(.caption.bold())
                                .foregroundStyle(Color(hex: "#8B5CF6"))
                        }

                        HStack {
                            Text("Nº do Contrato")
                            Spacer()
                            Text(doc.contractNumber)
                                .font(.system(.caption, design: .monospaced))
                        }

                        HStack {
                            Text("Saldo Devedor para Quitação Hoje")
                            Spacer()
                            Text(AppFormatters.currency(preview.remainingBalance))
                                .font(.system(.body, design: .monospaced))
                                .bold()
                                .foregroundStyle(Color(hex: "#10B981"))
                        }

                        HStack {
                            Text("Parcela Base Cadastrada")
                            Spacer()
                            Text(AppFormatters.currency(doc.installmentAmount))
                                .font(.system(.body, design: .monospaced))
                                .bold()
                        }

                        if let avgGrowth = doc.averageMonthlyInstallmentGrowth, avgGrowth > 0 {
                            HStack {
                                Text("Projeção Média Mensal (TP)")
                                Spacer()
                                Text("+\(AppFormatters.currency(avgGrowth))/mês")
                                    .font(.system(.caption, design: .monospaced))
                                    .bold()
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                            }
                        }

                        if !doc.scheduledInstallments.isEmpty {
                            HStack {
                                Text("Cronograma VLR. PARC Decrescente")
                                Spacer()
                                Text("\(doc.scheduledInstallments.count) parcelas mapeadas")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                        }

                        HStack {
                            Text("Taxa Efetiva Mensal")
                            Spacer()
                            Text(String(format: "%.4f%% a.m.", doc.monthlyInterestRate))
                                .font(.system(.caption, design: .monospaced))
                        }

                        HStack {
                            Text("Progresso Apurado (Ref. Salário)")
                            Spacer()
                            Text("\(preview.paidCount) pagas • \(preview.remainingCount) restantes (Total \(doc.totalInstallments))")
                                .font(.caption.bold())
                        }

                        Picker("Conta Bancária", selection: $selectedAccountId) {
                            ForEach(store.accounts) { acc in
                                Text(acc.name).tag(acc.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Importar Contrato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") {
                        guard let doc = parsedDocument, let preview = salaryPreview else { return }
                        let finalName = customContractName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? doc.name
                            : customContractName.trimmingCharacters(in: .whitespacesAndNewlines)

                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        _ = store.createCreditContract(
                            kind: doc.kind,
                            name: finalName,
                            contractNumber: doc.contractNumber,
                            loanSubtype: doc.loanSubtype,
                            financingSubtype: doc.financingSubtype,
                            amortizationSystem: doc.amortizationSystem,
                            totalContractedAmount: doc.totalContractedAmount,
                            outstandingBalance: preview.remainingBalance,
                            installmentAmount: doc.installmentAmount,
                            billingDay: manualSalaryBillingDay,
                            totalInstallments: doc.totalInstallments,
                            monthlyInterestRate: doc.monthlyInterestRate,
                            startDate: doc.startDate,
                            accountId: selectedAccountId,
                            categoryId: selectedCategoryId,
                            notes: doc.extractedNotes,
                            referenceDate: store.effectiveCurrentDate,
                            overridePastInstallmentsCount: preview.paidCount,
                            overrideFirstFutureBillingDate: preview.firstFutureBillingDate,
                            annualNominalInterestRate: doc.annualNominalInterestRate,
                            indexationRate: doc.indexationRate,
                            adminFee: doc.adminFee,
                            insuranceFee: doc.insuranceFee,
                            baseInstallmentAmount: doc.baseInstallmentAmount,
                            bankDueDay: doc.bankDueDay,
                            documentReferenceDate: doc.referenceDate,
                            maturityDate: doc.maturityDate,
                            scheduledInstallments: doc.scheduledInstallments,
                            averageMonthlyInstallmentGrowth: doc.averageMonthlyInstallmentGrowth
                        )
                        dismiss()
                    }
                    .bold()
                    .disabled(parsedDocument == nil)
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.pdf, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let secured = url.startAccessingSecurityScopedResource()
                    defer {
                        if secured { url.stopAccessingSecurityScopedResource() }
                    }
                    let extracted = ContractDocumentImportService.extractText(from: url)
                    if !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        rawDocumentText = extracted
                        parseCurrentText(expectedKind: defaultKind ?? .financing)
                    } else {
                        importErrorMessage = "Não foi possível ler o texto do arquivo selecionado."
                    }
                case .failure(let error):
                    importErrorMessage = "Erro ao abrir arquivo: \(error.localizedDescription)"
                }
            }
            .onAppear {
                if let firstAcc = store.accounts.first {
                    selectedAccountId = firstAcc.id
                }
                if let firstCat = store.categories.first(where: { $0.type == .expense }) ?? store.categories.first {
                    selectedCategoryId = firstCat.id
                }
                if defaultKind == .loan {
                    rawDocumentText = SampleContractDocumentsData.santanderLoanOCRText
                } else if defaultKind == .financing {
                    rawDocumentText = SampleContractDocumentsData.caixaFinancingOCRText
                }
                if !rawDocumentText.isEmpty {
                    parseCurrentText(expectedKind: defaultKind ?? .financing)
                }
            }
        }
    }

    private func parseCurrentText(expectedKind: CreditContractKind) {
        importErrorMessage = nil
        let parsed = ContractDocumentImportService.parseContractDocumentText(rawDocumentText, expectedKind: expectedKind)
        parsedDocument = parsed
        customContractName = parsed.name
        manualSalaryBillingDay = parsed.billingDay
    }
}

// MARK: - Planejador Dinâmico de Amortização (2 Estados: Edição vs Visualização + Início, Meio e Fim)

public struct AmortizationPlannerSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let contract: CreditContract
    @Environment(\.dismiss) var dismiss

    @State private var draftPlan: AmortizationPlan
    @State private var isEditingMode: Bool
    @State private var newItemDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var newItemAmountText: String = "R$ 2.000,00"
    @State private var newItemStrategy: AmortizationRecalculationMode = .reduceTerm
    @State private var newItemFundingSource: AmortizationFundingSource = .cash
    @State private var newItemNote: String = ""
    @State private var isPresentingManualSimulator: Bool = false
    @State private var isConfirmingDeletePlan: Bool = false

    public init(store: FinancialDataStore, contract: CreditContract) {
        self.store = store
        self.contract = contract
        let hasSaved = store.hasSavedAmortizationPlan(for: contract.id)
        let initialPlan = store.amortizationPlan(for: contract.id) ?? AmortizationPlan(
            contractId: contract.id,
            generationMode: .manual,
            billingDay: contract.billingDay,
            incomeCommitmentPercentage: Decimal(30),
            defaultRecalculationMode: .reduceTerm,
            estimatedMonthlyTR: LoanProjectionEngine.toDecimal(contract.estimatedMonthlyTR ?? 0.0),
            items: []
        )
        _draftPlan = State(initialValue: initialPlan)
        _isEditingMode = State(initialValue: !hasSaved)
    }

    private var activePlanForProjection: AmortizationPlan {
        if isEditingMode {
            return draftPlan
        }
        return store.amortizationPlan(for: contract.id) ?? draftPlan
    }

    private var projectionResult: LoanProjectionResult? {
        store.simulateAmortizationPlanPreview(for: contract.id, draftPlan: activePlanForProjection)
    }

    private var isLoanAlreadyPaidOffByPlan: Bool {
        guard let proj = projectionResult else { return false }
        return proj.doesPlanAchieveFullPayoff && !activePlanForProjection.items.isEmpty
    }

    private var maxAvailableToAmortizeOnSelectedDate: Double {
        store.maxAvailableLoanBalanceToAmortize(
            for: contract.id,
            draftItems: activePlanForProjection.items,
            onDate: newItemDate,
            estimatedMonthlyTR: activePlanForProjection.estimatedMonthlyTR
        )
    }

    private var parsedTypedContribution: Double {
        let raw = AppFormatters.parseAmount(newItemAmountText) ?? 0.0
        return min(max(0.0, raw), maxAvailableToAmortizeOnSelectedDate)
    }

    private var liveExpectedBalanceAfterContribution: Double {
        store.expectedMonthEndCashBalance(
            for: newItemDate,
            contractId: contract.id,
            draftPlan: activePlanForProjection,
            draftProjection: projectionResult,
            additionalTypingOutflow: (isEditingMode && newItemFundingSource == .cash) ? parsedTypedContribution : 0.0
        )
    }

    private var liveLoanBalanceAfterContribution: Double {
        max(0.0, maxAvailableToAmortizeOnSelectedDate - (isEditingMode ? parsedTypedContribution : 0.0))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Atalho superior para Amortização Manual Imediata + Modo do Planejador
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: isEditingMode ? "pencil.and.outline" : "checkmark.shield.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(isEditingMode ? "Modo Criação / Edição" : "Planejamento Salvo")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: isEditingMode ? "#8B5CF6" : "#10B981"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: isEditingMode ? "#8B5CF6" : "#10B981").opacity(0.15)))

                        Spacer()

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            isPresentingManualSimulator = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.circle.fill")
                                Text("Amortização Manual")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#0284C7"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                    }

                    // Jornada em 3 Cards: 1. INÍCIO → 2. MEIO → 3. FIM
                    if let proj = projectionResult {
                        journeyThreeCardsSection(proj: proj)
                    }

                    // Se estiver em modo Edição, exibe o Painel de Inserção de Aportes
                    if isEditingMode {
                        contributionInsertionCard
                    } else {
                        // Ações do Modo Visualização (Editar ou Remover Planejamento)
                        HStack(spacing: 12) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if let saved = store.amortizationPlan(for: contract.id) {
                                    draftPlan = saved
                                }
                                withAnimation {
                                    isEditingMode = true
                                }
                            } label: {
                                Label("Editar Planejamento", systemImage: "pencil")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color(hex: "#8B5CF6")))
                            }
                            .buttonStyle(.plain)

                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                isConfirmingDeletePlan = true
                            } label: {
                                Label("Remover", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: "#EF4444"))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color(hex: "#EF4444").opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Lista Unificada Clean: Aportes Planejados & Evolução Mês a Mês
                    if let proj = projectionResult {
                        unifiedEvolutionAndContributionsSection(proj: proj)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(LiquidColors.background(for: .dark).ignoresSafeArea())
            .navigationTitle(isEditingMode ? "Planejar Amortização" : "Ver Planejamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                if isEditingMode {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salvar") {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            _ = store.saveAmortizationPlan(
                                contractId: contract.id,
                                generationMode: draftPlan.generationMode,
                                billingDay: draftPlan.billingDay,
                                incomeCommitmentPercentage: draftPlan.incomeCommitmentPercentage,
                                defaultRecalculationMode: draftPlan.defaultRecalculationMode,
                                estimatedMonthlyTR: draftPlan.estimatedMonthlyTR,
                                draftItems: draftPlan.items
                            )
                            store.budgetProjectionScenario = .withPlanning
                            withAnimation {
                                isEditingMode = false
                            }
                        }
                        .bold()
                        .disabled(draftPlan.items.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $isPresentingManualSimulator) {
                AmortizationSimulatorSheet(store: store, contract: contract)
            }
            .alert("Remover Planejamento", isPresented: $isConfirmingDeletePlan) {
                Button("Cancelar", role: .cancel) {}
                Button("Remover Plano", role: .destructive) {
                    store.deleteAmortizationPlan(for: contract.id)
                    dismiss()
                }
            } message: {
                Text("Deseja cancelar e remover este planejamento de amortização? As transações futuras voltarão ao cenário base original.")
            }
        }
    }

    // MARK: - 1. INÍCIO → 2. MEIO → 3. FIM
    private func journeyThreeCardsSection(proj: LoanProjectionResult) -> some View {
        let totalPlanned = activePlanForProjection.items
            .filter { $0.status == .pending || $0.status == .executed }
            .reduce(0.0) { $0 + $1.amountDouble }
        let interestSavedDouble = NSDecimalNumber(decimal: proj.totalInterestSaved).doubleValue
        let startBal = NSDecimalNumber(decimal: proj.currentRealBalance).doubleValue
        let endBal = NSDecimalNumber(decimal: proj.projectedFinalBalanceAfterPlan).doubleValue
        let achievesPayoff = proj.doesPlanAchieveFullPayoff && !activePlanForProjection.items.isEmpty

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                // 1. INÍCIO
                LiquidGlassCard(cornerRadius: 16, padding: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. INÍCIO (ATUAL)")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(Color.secondary)
                        Text(AppFormatters.currency(startBal))
                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#EF4444"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("\(proj.originalRemainingMonths) parcelas restantes")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 2. MEIO
                LiquidGlassCard(cornerRadius: 16, padding: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2. MEIO (PLANO)")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(Color(hex: "#8B5CF6"))
                        Text(AppFormatters.currency(totalPlanned))
                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#8B5CF6"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("Economia: \(AppFormatters.currency(interestSavedDouble))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "#10B981"))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // 3. FIM
            LiquidGlassCard(cornerRadius: 16, padding: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("3. FIM (RESULTADO DO PLANEJAMENTO)")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(Color(hex: achievesPayoff ? "#10B981" : "#0284C7"))
                        if achievesPayoff {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color(hex: "#10B981"))
                                Text("QUITAÇÃO TOTAL DO EMPRÉSTIMO!")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                        } else {
                            Text("Saldo Pós-Plano: \(AppFormatters.currency(endBal))")
                                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.primary)
                        }
                        Text("\(proj.projectedActiveMonths) parcelas restantes (\(proj.monthsSaved) eliminadas)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Última Parcela")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                        Text(AppFormatters.monthYear(proj.projectedMaturityDate))
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(achievesPayoff ? Color(hex: "#10B981").opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
    }

    // MARK: - Painel de Inserção de Aportes (Manual e Automático % da Sobra)
    private var contributionInsertionCard: some View {
        let commitmentPctDouble = NSDecimalNumber(decimal: draftPlan.incomeCommitmentPercentage).doubleValue

        return LiquidGlassCard(cornerRadius: 18, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Modo de Planejamento", selection: $draftPlan.generationMode) {
                    ForEach(AmortizationPlanGenerationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if isLoanAlreadyPaidOffByPlan {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(hex: "#10B981"))
                        Text("Este planejamento já atinge a QUITAÇÃO TOTAL do contrato. Não é necessário adicionar novos aportes.")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#10B981").opacity(0.14)))
                } else if draftPlan.generationMode == .manual {
                    VStack(alignment: .leading, spacing: 10) {
                        DatePicker("Data do Aporte", selection: $newItemDate, displayedComponents: [.date])
                            .font(.system(size: 13, weight: .semibold))

                        // Visibilidade em Tempo Real na mesma linha: Saldo Esperado Fim do Mês & Saldo do Empréstimo Após Amortização
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Saldo Esperado Fim do Mês")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                Text(AppFormatters.currency(liveExpectedBalanceAfterContribution))
                                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(liveExpectedBalanceAfterContribution >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Saldo Empréstimo Após Aporte")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                Text(liveLoanBalanceAfterContribution <= 0.01 ? "QUITADO (R$ 0,00)" : AppFormatters.currency(liveLoanBalanceAfterContribution))
                                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(liveLoanBalanceAfterContribution <= 0.01 ? Color(hex: "#10B981") : Color.primary)
                            }
                        }
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))

                        HStack {
                            Text("Valor do Aporte (Máx: \(AppFormatters.currency(maxAvailableToAmortizeOnSelectedDate)))")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            BRLCurrencyTextField("R$ 0,00", text: $newItemAmountText)
                        }

                        Picker("Estratégia", selection: $newItemStrategy) {
                            Text("Reduzir Prazo").tag(AmortizationRecalculationMode.reduceTerm)
                            Text("Reduzir Parcela").tag(AmortizationRecalculationMode.reduceInstallment)
                        }
                        .pickerStyle(.segmented)

                        if contract.kind == .financing {
                            Picker("Fonte de Recursos", selection: $newItemFundingSource) {
                                ForEach(AmortizationFundingSource.allCases) { src in
                                    Text(src.rawValue).tag(src)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Button {
                            addManualPlannedContribution()
                        } label: {
                            HStack {
                                Image(systemName: liveLoanBalanceAfterContribution <= 0.01 ? "checkmark.seal.fill" : "plus.circle.fill")
                                Text(liveLoanBalanceAfterContribution <= 0.01 ? "Incluir Aporte de Quitação Total" : "Adicionar Aporte ao Plano")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color(hex: liveLoanBalanceAfterContribution <= 0.01 ? "#10B981" : "#8B5CF6")))
                        }
                        .buttonStyle(.plain)
                        .disabled(parsedTypedContribution <= 0.01 || maxAvailableToAmortizeOnSelectedDate <= 0.01)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Alocar da Sobra Mensal:")
                                .font(.system(size: 12.5, weight: .semibold))
                            Spacer()
                            Text("\(Int(commitmentPctDouble))%")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#8B5CF6"))
                        }

                        Slider(
                            value: Binding(
                                get: { NSDecimalNumber(decimal: draftPlan.incomeCommitmentPercentage).doubleValue },
                                set: { draftPlan.incomeCommitmentPercentage = Decimal(Int($0)) }
                            ),
                            in: 5...100,
                            step: 5
                        )
                        .tint(Color(hex: "#8B5CF6"))

                        Button {
                            generateAutomaticSurplusContributions()
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Gerar Aportes com \(Int(commitmentPctDouble))% da Sobra")
                            }
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color(hex: "#8B5CF6")))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Lista Unificada Clean: Evolução Mês a Mês com Aportes Planejados
    private func unifiedEvolutionAndContributionsSection(proj: LoanProjectionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Seção 1: Aportes Planejados
            if !activePlanForProjection.items.isEmpty {
                LiquidGlassCard(cornerRadius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Aportes Planejados (\(activePlanForProjection.items.count))")
                                .font(.system(size: 13.5, weight: .bold))
                            Spacer()
                            if isEditingMode {
                                Button("Limpar Todos") {
                                    draftPlan.items.removeAll()
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#EF4444"))
                            }
                        }

                        ForEach(activePlanForProjection.items.sorted(by: { $0.date < $1.date })) { item in
                            let outcome = proj.plannedItemOutcomes[item.id]
                            let leadsToPayoff = outcome?.isFullPayoffStep == true
                            let expectedMonthSurplus = store.expectedMonthEndCashBalance(
                                for: item.date,
                                contractId: contract.id,
                                draftPlan: activePlanForProjection,
                                draftProjection: proj
                            )
                            let balanceAfter = NSDecimalNumber(decimal: outcome?.remainingBalanceAfter ?? 0).doubleValue
                            let effectiveAmt = NSDecimalNumber(decimal: outcome?.effectiveAmortization ?? item.amount).doubleValue

                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: leadsToPayoff ? "checkmark.seal.fill" : "calendar.badge.plus")
                                            .foregroundStyle(Color(hex: leadsToPayoff ? "#10B981" : "#8B5CF6"))
                                        Text(AppFormatters.shortDate(item.date))
                                            .font(.system(size: 12.5, weight: .bold))
                                        if leadsToPayoff {
                                            Text("QUITAÇÃO TOTAL")
                                                .font(.system(size: 9, weight: .heavy))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1.5)
                                                .background(Capsule().fill(Color(hex: "#10B981").opacity(0.2)))
                                                .foregroundStyle(Color(hex: "#10B981"))
                                        }
                                    }
                                    Spacer()
                                    Text(AppFormatters.currency(effectiveAmt))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: leadsToPayoff ? "#10B981" : "#8B5CF6"))

                                    if isEditingMode {
                                        Button {
                                            draftPlan.items.removeAll { $0.id == item.id }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Color.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                // Mesma linha: Saldo Esperado Fim do Mês + Saldo do Empréstimo Após Amortização
                                HStack {
                                    Text("Saldo Fim do Mês: \(AppFormatters.currency(expectedMonthSurplus))")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(expectedMonthSurplus >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                    Spacer()
                                    Text("Saldo Empréstimo: \(leadsToPayoff ? "R$ 0,00 (Quitado)" : AppFormatters.currency(balanceAfter))")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(leadsToPayoff ? Color(hex: "#10B981") : Color.secondary)
                                }
                            }
                            .padding(9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: leadsToPayoff ? "#10B981" : "#8B5CF6").opacity(0.09))
                            )
                        }
                    }
                }
            }

            // Seção 2: Evolução Mês a Mês Unificada Clean
            LiquidGlassCard(cornerRadius: 18, padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Evolução Mês a Mês e Aportes")
                        .font(.system(size: 13.5, weight: .bold))

                    ForEach(proj.timeline.prefix(36)) { row in
                        let isExtra = row.eventKind == .extraAmortization || row.eventKind == .fgtsAmortization
                        let isShadowed = row.status == .shadowed
                        let rowBalanceAfter = NSDecimalNumber(decimal: row.finalBalance).doubleValue
                        let rowAmount = NSDecimalNumber(decimal: row.totalBudgetOutflow).doubleValue
                        let isZeroPayoffRow = rowBalanceAfter <= 0.01 && !isShadowed
                        let monthEndExpected = store.expectedMonthEndCashBalance(
                            for: row.date,
                            contractId: contract.id,
                            draftPlan: activePlanForProjection,
                            draftProjection: proj
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color(hex: isZeroPayoffRow ? "#10B981" : (isExtra ? "#8B5CF6" : (isShadowed ? "#6B7280" : "#0284C7"))))
                                        .frame(width: 7, height: 7)
                                    Text(AppFormatters.monthYear(row.date))
                                        .font(.system(size: 11.5, weight: .bold))
                                    Text("• \(row.title)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(isShadowed ? Color.secondary : Color.primary)
                                        .strikethrough(isShadowed, color: .secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(isShadowed ? "Eliminada" : AppFormatters.currency(rowAmount))
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isZeroPayoffRow ? Color(hex: "#10B981") : (isExtra ? Color(hex: "#8B5CF6") : Color.primary))
                            }

                            if !isShadowed {
                                HStack {
                                    Text("Saldo Fim do Mês: \(AppFormatters.currency(monthEndExpected))")
                                        .font(.system(size: 9.5, design: .monospaced))
                                        .foregroundStyle(monthEndExpected >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                    Spacer()
                                    Text(isZeroPayoffRow ? "Saldo Empréstimo: R$ 0,00 (QUITAÇÃO)" : "Saldo Empréstimo: \(AppFormatters.currency(rowBalanceAfter))")
                                        .font(.system(size: 9.5, weight: isZeroPayoffRow ? .heavy : .medium, design: .monospaced))
                                        .foregroundStyle(isZeroPayoffRow ? Color(hex: "#10B981") : Color.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        Divider().opacity(0.25)
                    }
                }
            }
        }
    }

    private func addManualPlannedContribution() {
        let clampedAmount = parsedTypedContribution
        guard clampedAmount > 0.01 else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let item = PlannedAmortization(
            contractId: contract.id,
            date: newItemDate,
            amount: Decimal(string: String(format: "%.2f", clampedAmount)) ?? 0,
            source: newItemFundingSource,
            mode: contract.kind == .loan ? .reduceTerm : newItemStrategy,
            status: .pending,
            notes: newItemNote.isEmpty ? "Aporte Planejado" : newItemNote
        )
        draftPlan.items.append(item)
        draftPlan.items.sort { $0.date < $1.date }
        draftPlan.updatedAt = Date()

        if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: newItemDate) {
            newItemDate = nextMonth
        }
    }

    private func generateAutomaticSurplusContributions() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let generatedPlan = store.generateAutomaticAmortizationPlan(
            contractId: contract.id,
            billingDay: draftPlan.billingDay,
            incomeCommitmentPercentage: draftPlan.incomeCommitmentPercentage,
            mode: contract.kind == .loan ? .reduceTerm : draftPlan.defaultRecalculationMode,
            estimatedMonthlyTR: draftPlan.estimatedMonthlyTR
        ) {
            draftPlan = generatedPlan
        }
    }
}
