// Sources/FinSense/Views/Transactions/TransactionDetailSheet.swift
import SwiftUI

public struct TransactionDetailSheet: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @Environment(\.dismiss) var dismiss

    public var editingTransaction: FinancialTransaction?

    @State private var name: String = ""
    @State private var details: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    @State private var type: TransactionType = .expense
    @State private var isPaid: Bool = true
    @State private var selectedCategoryId: UUID = UUID()
    @State private var selectedAccountId: UUID = UUID()
    @State private var recurrenceMode: TransactionRecurrenceMode = .single
    @State private var installmentTotal: Int = 12

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        editingTransaction: FinancialTransaction? = nil
    ) {
        self.store = store
        self.syncService = syncService
        self.editingTransaction = editingTransaction

        let initialType: TransactionType
        if let editing = editingTransaction {
            initialType = editing.type
        } else {
            initialType = .expense
        }

        let fallbackAccId = editingTransaction?.accountId
            ?? store.accounts.first?.id
            ?? UUID()

        let fallbackCatId = editingTransaction?.categoryId
            ?? store.categories.first(where: { $0.type == initialType })?.id
            ?? store.categories.first?.id
            ?? UUID()

        if let editing = editingTransaction {
            _name = State(initialValue: editing.name)
            _details = State(initialValue: editing.details)
            _amountString = State(initialValue: String(format: "%.2f", editing.amount))
            _date = State(initialValue: editing.date)
            _type = State(initialValue: editing.type)
            _isPaid = State(initialValue: editing.isPaid)
            _selectedCategoryId = State(initialValue: editing.categoryId)
            _selectedAccountId = State(initialValue: editing.accountId)
            _recurrenceMode = State(initialValue: editing.recurrenceMode)
            _installmentTotal = State(initialValue: editing.installmentTotal ?? 12)
        } else {
            _name = State(initialValue: "")
            _details = State(initialValue: "")
            _amountString = State(initialValue: "")
            _date = State(initialValue: Date())
            _type = State(initialValue: initialType)
            _isPaid = State(initialValue: true)
            _selectedCategoryId = State(initialValue: fallbackCatId)
            _selectedAccountId = State(initialValue: fallbackAccId)
            _recurrenceMode = State(initialValue: .single)
            _installmentTotal = State(initialValue: 12)
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Dados Principais") {
                    Picker("Tipo", selection: $type) {
                        Text("Despesa").tag(TransactionType.expense)
                        Text("Receita").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    TextField("Descrição (ex: Supermercado, Aluguel)", text: $name)

                    HStack {
                        Text("Valor (R$)")
                        Spacer()
                        TextField("0,00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Data", selection: $date, displayedComponents: [.date])

                    Toggle("Já Liquidado (Pago)", isOn: $isPaid)
                }

                Section("Classificação") {
                    Picker("Conta Bancária", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            HStack {
                                Image(systemName: acc.iconSymbol)
                                Text(acc.name)
                            }
                            .tag(acc.id)
                        }
                    }

                    Picker("Categoria", selection: $selectedCategoryId) {
                        ForEach(store.categories.filter { $0.type == type }) { cat in
                            HStack {
                                Image(systemName: cat.iconSymbol)
                                Text(cat.name)
                            }
                            .tag(cat.id)
                        }
                    }
                }

                Section("Recorrência & Parcelamento") {
                    Picker("Modo", selection: $recurrenceMode) {
                        Text("Único").tag(TransactionRecurrenceMode.single)
                        if type == .expense {
                            Text("Parcelado").tag(TransactionRecurrenceMode.installment)
                        }
                        Text("Recorrente Mensal").tag(TransactionRecurrenceMode.recurring)
                    }

                    if recurrenceMode == .installment && type == .expense {
                        Stepper("Parcelas: \(installmentTotal)x", value: $installmentTotal, in: 2...120)
                    }
                }

                Section("Observações") {
                    TextField("Detalhes adicionais (opcional)", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(editingTransaction != nil ? "Editar Lançamento" : "Nova Transação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveTransaction()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || AppFormatters.parseAmount(amountString) == nil)
                }
            }
            .onAppear {
                if !store.accounts.contains(where: { $0.id == selectedAccountId }), let firstAcc = store.accounts.first {
                    selectedAccountId = firstAcc.id
                }
                if !store.categories.contains(where: { $0.id == selectedCategoryId }), let firstCat = store.categories.first(where: { $0.type == type }) ?? store.categories.first {
                    selectedCategoryId = firstCat.id
                }
            }
            .onChange(of: type) { _, newType in
                if store.categories.first(where: { $0.id == selectedCategoryId })?.type != newType,
                   let firstCat = store.categories.first(where: { $0.type == newType }) {
                    selectedCategoryId = firstCat.id
                }
            }
        }
    }

    private func saveTransaction() {
        guard let amount = AppFormatters.parseAmount(amountString), amount > 0 else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let effectiveAccountId: UUID = store.accounts.contains(where: { $0.id == selectedAccountId })
            ? selectedAccountId
            : (store.accounts.first?.id ?? selectedAccountId)

        let effectiveCategoryId: UUID = store.categories.contains(where: { $0.id == selectedCategoryId })
            ? selectedCategoryId
            : (store.categories.first(where: { $0.type == type })?.id ?? store.categories.first?.id ?? selectedCategoryId)

        if var editing = editingTransaction {
            editing.name = name
            editing.details = details
            editing.amount = amount
            editing.date = date
            editing.type = type
            editing.isPaid = isPaid
            editing.categoryId = effectiveCategoryId
            editing.accountId = effectiveAccountId
            editing.recurrenceMode = recurrenceMode
            if recurrenceMode == .installment {
                editing.installmentTotal = installmentTotal
            }
            store.updateTransaction(editing)
        } else {
            if recurrenceMode == .installment && type == .expense && installmentTotal > 1 {
                // Cria a série parcelada
                let seriesId = UUID()
                let installmentAmount = amount / Double(installmentTotal)
                let cal = Calendar.current
                for i in 1...installmentTotal {
                    let installmentDate = cal.date(byAdding: .month, value: i - 1, to: date) ?? date
                    store.createTransaction(
                        name: "\(name) (\(i)/\(installmentTotal))",
                        details: details,
                        amount: installmentAmount,
                        date: installmentDate,
                        type: type,
                        isPaid: i == 1 ? isPaid : false,
                        categoryId: effectiveCategoryId,
                        accountId: effectiveAccountId,
                        recurrenceMode: .installment,
                        installmentIndex: i,
                        installmentTotal: installmentTotal,
                        seriesGroupId: seriesId
                    )
                }
            } else {
                store.createTransaction(
                    name: name,
                    details: details,
                    amount: amount,
                    date: date,
                    type: type,
                    isPaid: isPaid,
                    categoryId: effectiveCategoryId,
                    accountId: effectiveAccountId,
                    recurrenceMode: recurrenceMode
                )
            }
        }

        dismiss()
    }
}
