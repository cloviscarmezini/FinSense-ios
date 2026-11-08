// Sources/FinSense/Views/FinanceHub/DebtsManagerView.swift
import SwiftUI

public struct DebtsManagerView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var isAddPresented: Bool = false
    @State private var settlingDebt: DebtItem? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Banner de Dívida Consolidada
                    LiquidGlassCard(cornerRadius: 22, padding: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Passivo em Dívidas em Aberto")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.secondary)

                                Text(AppFormatters.currency(store.totalDebtAmount))
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#EF4444"))
                            }

                            Spacer()

                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color(hex: "#EF4444").opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    if store.debts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color(hex: "#10B981"))
                            Text("Nenhuma dívida cadastrada!")
                                .font(.system(size: 15, weight: .bold))
                            Text("Parabéns, seu cadastro não possui pendências registradas.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.debts) { debt in
                                LiquidGlassCard(cornerRadius: 18, padding: 14) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: debt.colorHex).opacity(0.18))
                                                    .frame(width: 38, height: 38)
                                                Image(systemName: debt.iconSymbol)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(Color(hex: debt.colorHex))
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(debt.name)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(Color.primary)

                                                if debt.isPaid {
                                                    Text("Quitado")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#10B981"))
                                                } else {
                                                    Text("Em aberto")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#EF4444"))
                                                }
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(AppFormatters.currency(debt.originalAmount))
                                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(debt.isPaid ? Color.secondary : Color.primary)

                                                if let negotiated = debt.negotiatedAmount {
                                                    Text("Acordo: \(AppFormatters.currency(negotiated))")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#10B981"))
                                                }
                                            }
                                        }

                                        if !debt.isPaid {
                                            HStack {
                                                Button {
                                                    settlingDebt = debt
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "checkmark.circle.fill")
                                                        Text("Registrar Quitação")
                                                    }
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(Color(hex: "#10B981"))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().fill(Color(hex: "#10B981").opacity(0.12)))
                                                }
                                                .buttonStyle(.plain)

                                                Spacer()

                                                Button {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    store.deleteDebt(debt.id)
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
                    }
                }
            }
        }
        .navigationTitle("Dívidas & Acordos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isAddPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            DebtEditorSheet(store: store)
        }
        .sheet(item: $settlingDebt) { debt in
            SettleDebtSheet(store: store, debt: debt)
        }
    }
}

public struct DebtEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var originalAmountString: String = "0,00"
    @State private var notes: String = ""

    public var body: some View {
        NavigationStack {
            Form {
                Section("Dados da Dívida") {
                    TextField("Credor / Nome (ex: Cartão Sam's Club, Serasa)", text: $name)

                    HStack {
                        Text("Valor Original (R$)")
                        Spacer()
                        TextField("0,00", text: $originalAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    TextField("Observações / Histórico de Negociação", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Nova Dívida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let amount = AppFormatters.parseAmount(originalAmountString) ?? 0.0
                        store.createDebt(name: name, originalAmount: amount, notes: notes)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

public struct SettleDebtSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let debt: DebtItem
    @Environment(\.dismiss) var dismiss

    @State private var negotiatedAmountString: String = ""
    @State private var selectedAccountId: UUID = UUID()

    public init(store: FinancialDataStore, debt: DebtItem) {
        self.store = store
        self.debt = debt
        _negotiatedAmountString = State(initialValue: String(format: "%.2f", debt.originalAmount))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Valor de Quitação Acordado") {
                    HStack {
                        Text("Valor Negociado (R$)")
                        Spacer()
                        TextField("0,00", text: $negotiatedAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Conta de Pagamento", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(acc.id)
                        }
                    }
                }
            }
            .navigationTitle("Quitar: \(debt.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar Quitação") {
                        guard let amount = AppFormatters.parseAmount(negotiatedAmountString), amount > 0 else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.markDebtPaid(debtId: debt.id, negotiatedAmount: amount, paidFromAccountId: selectedAccountId)
                        dismiss()
                    }
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
