// Sources/FinSense/Views/FinanceHub/CreditContractsView.swift
import SwiftUI

public struct CreditContractsView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var isAddContractPresented: Bool = false
    @State private var simulatingContract: CreditContract? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if store.contracts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "house.and.flag.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                            Text("Nenhum contrato cadastrado")
                                .font(.system(size: 15, weight: .bold))
                            Text("Cadastre seu financiamento imobiliário, veicular ou consignado.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(store.contracts) { contract in
                                LiquidGlassCard(cornerRadius: 20, padding: 16) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: "#0284C7").opacity(0.18))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: contract.iconSymbol)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(Color(hex: "#0284C7"))
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(contract.name)
                                                    .font(.system(size: 15, weight: .bold))
                                                Text("\(contract.subtypeDisplayName) • \(contract.amortizationSystem == .sac ? "SAC" : "PRICE")")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.secondary)
                                            }

                                            Spacer()

                                            if contract.isSettled {
                                                Text("Quitado")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(Color(hex: "#10B981"))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Capsule().fill(Color(hex: "#10B981").opacity(0.15)))
                                            }
                                        }

                                        Divider().opacity(0.4)

                                        HStack(alignment: .top, spacing: 14) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Saldo Devedor")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.secondary)
                                                Text(AppFormatters.currency(contract.outstandingBalance ?? contract.totalContractedAmount))
                                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Parcela Mensal")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.secondary)
                                                Text(AppFormatters.currency(contract.installmentAmount))
                                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Juros a.m.")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.secondary)
                                                Text(String(format: "%.2f%%", contract.monthlyInterestRate))
                                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            }
                                        }

                                        if !contract.isSettled {
                                            HStack {
                                                Button {
                                                    simulatingContract = contract
                                                } label: {
                                                    HStack(spacing: 5) {
                                                        Image(systemName: "sparkles")
                                                        Text("Simular Amortização")
                                                    }
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Capsule().fill(Color(hex: "#0284C7")))
                                                }
                                                .buttonStyle(.plain)

                                                Spacer()

                                                Button {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    store.deleteContract(contract.id)
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
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
            }
        }
        .navigationTitle("Financiamentos")
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
            ContractEditorSheet(store: store)
        }
        .sheet(item: $simulatingContract) { contract in
            AmortizationSimulatorSheet(store: store, contract: contract)
        }
    }
}

public struct ContractEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    @Environment(\.dismiss) var dismiss

    @State private var kind: CreditContractKind = .financing
    @State private var name: String = ""
    @State private var totalAmountString: String = "0,00"
    @State private var installmentAmountString: String = "0,00"
    @State private var totalInstallments: Int = 360
    @State private var interestRateString: String = "0,85"
    @State private var billingDay: Int = 10
    @State private var amortizationSystem: AmortizationSystem = .sac
    @State private var selectedAccountId: UUID = UUID()
    @State private var selectedCategoryId: UUID = UUID()

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
                        Text("Saldo Financiado (R$)")
                        Spacer()
                        TextField("0,00", text: $totalAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Valor da Parcela (R$)")
                        Spacer()
                        TextField("0,00", text: $installmentAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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

public struct AmortizationSimulatorSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let contract: CreditContract
    @Environment(\.dismiss) var dismiss

    @State private var amortizeAmountString: String = "5000,00"
    @State private var mode: AmortizationRecalculationMode = .reduceTerm
    @State private var selectedAccountId: UUID = UUID()
    @State private var isConfirmingRealAmortization: Bool = false

    public init(store: FinancialDataStore, contract: CreditContract) {
        self.store = store
        self.contract = contract
    }

    public var body: some View {
        NavigationStack {
            let currentBalance = contract.outstandingBalance ?? contract.totalContractedAmount
            let amortizeVal = AppFormatters.parseAmount(amortizeAmountString) ?? 0.0
            let newBalance = max(0, currentBalance - amortizeVal)

            let monthlyRate = (contract.monthlyInterestRate / 100.0)
            let remainingInstallments = max(1, contract.totalInstallments - contract.pastInstallmentsElapsedAtCreation)

            // Estimativas matemáticas SAC / Price
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
                        Text("Valor a Amortizar (R$)")
                        Spacer()
                        TextField("5000,00", text: $amortizeAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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
                        Text("Economia Total em Juros Futuros")
                        Spacer()
                        Text(AppFormatters.currency(estimatedSavings))
                            .bold()
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                }

                Section("Efetivação Real (Debitar de Conta)") {
                    Picker("Conta de Débito", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(acc.id)
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
            .navigationTitle("Simulador de Amortização")
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
                        store.recordAmortization(
                            contractId: contract.id,
                            amount: val,
                            mode: mode,
                            paidFromAccountId: selectedAccountId
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
