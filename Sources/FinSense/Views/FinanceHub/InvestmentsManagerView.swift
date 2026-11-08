// Sources/FinSense/Views/FinanceHub/InvestmentsManagerView.swift
import SwiftUI

public struct InvestmentsManagerView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var isAddInvestmentPresented: Bool = false
    @State private var activeMovementInvestment: InvestmentItem? = nil

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
                                    VStack(alignment: .leading, spacing: 10) {
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

                                            Text(AppFormatters.currency(inv.balance))
                                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                                .foregroundStyle(Color.primary)
                                        }

                                        HStack(spacing: 10) {
                                            Button {
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
    @State private var initialBalanceString: String = "0,00"
    @State private var selectedAccountId: UUID = UUID()
    @State private var colorHex: String = "#10B981"

    public var body: some View {
        NavigationStack {
            Form {
                Section("Dados do Ativo") {
                    TextField("Nome (ex: CDB 110% CDI, Tesouro Selic)", text: $name)
                    TextField("Grupo (ex: Renda Fixa, Ações, Cofrinho)", text: $groupName)

                    HStack {
                        Text("Saldo Atual (R$)")
                        Spacer()
                        TextField("0,00", text: $initialBalanceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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
    @Environment(\.dismiss) var dismiss

    @State private var movementType: InvestmentMovementType = .deposit
    @State private var amountString: String = ""
    @State private var selectedSourceAccountId: UUID = UUID()
    @State private var notes: String = ""

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
                        Text("Valor (R$)")
                        Spacer()
                        TextField("0,00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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
                if let first = store.accounts.first {
                    selectedSourceAccountId = first.id
                }
            }
        }
    }
}
