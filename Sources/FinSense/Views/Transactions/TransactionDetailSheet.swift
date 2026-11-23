// Sources/FinSense/Views/Transactions/TransactionDetailSheet.swift
import SwiftUI

public struct TransactionDetailSheet: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @Environment(\.dismiss) var dismiss

    public var editingTransaction: FinancialTransaction?
    public var initialCreditCardId: UUID?

    @State private var name: String = ""
    @State private var details: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    @State private var type: TransactionType = .expense
    @State private var isPaid: Bool = true
    @State private var selectedCategoryId: UUID = UUID()
    @State private var selectedAccountId: UUID = UUID()
    @State private var paymentMethodIsCard: Bool = false
    @State private var selectedCreditCardId: UUID = UUID()
    @State private var recurrenceMode: TransactionRecurrenceMode = .single
    @State private var installmentTotal: Int = 12
    @State private var showDeleteConfirmation: Bool = false

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        editingTransaction: FinancialTransaction? = nil,
        initialCreditCardId: UUID? = nil
    ) {
        self.store = store
        self.syncService = syncService
        self.editingTransaction = editingTransaction
        self.initialCreditCardId = initialCreditCardId

        let initialType: TransactionType
        if let editing = editingTransaction {
            initialType = editing.type
        } else {
            initialType = .expense
        }

        let isEditingCardPurchase = editingTransaction?.isCreditCardExpense ?? false
        let initialUseCard = editingTransaction != nil ? isEditingCardPurchase : (initialCreditCardId != nil)

        let fallbackAccId = (isEditingCardPurchase ? nil : editingTransaction?.accountId)
            ?? store.accounts.first?.id
            ?? UUID()

        let fallbackCardId = editingTransaction?.creditCardId
            ?? initialCreditCardId
            ?? store.creditCards.first?.id
            ?? UUID()

        let fallbackCatId = editingTransaction?.categoryId
            ?? store.categories.first(where: { $0.type == initialType })?.id
            ?? store.categories.first?.id
            ?? UUID()

        if let editing = editingTransaction {
            _name = State(initialValue: editing.name)
            _details = State(initialValue: editing.details)
            _amountString = State(initialValue: AppFormatters.currency(editing.amount))
            _date = State(initialValue: editing.date)
            _type = State(initialValue: editing.type)
            _isPaid = State(initialValue: editing.isPaid)
            _selectedCategoryId = State(initialValue: editing.categoryId)
            _selectedAccountId = State(initialValue: fallbackAccId)
            _paymentMethodIsCard = State(initialValue: initialUseCard)
            _selectedCreditCardId = State(initialValue: fallbackCardId)
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
            _paymentMethodIsCard = State(initialValue: initialUseCard)
            _selectedCreditCardId = State(initialValue: fallbackCardId)
            _recurrenceMode = State(initialValue: .single)
            _installmentTotal = State(initialValue: 12)
        }
    }

    private var usesCreditCard: Bool {
        type == .expense && paymentMethodIsCard && !store.creditCards.isEmpty
    }

    private var selectedCard: CreditCard? {
        store.creditCard(for: selectedCreditCardId) ?? store.creditCards.first
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
                        Text("Valor")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $amountString)
                    }

                    DatePicker("Data", selection: $date, displayedComponents: [.date])

                    if !usesCreditCard {
                        Toggle("Já Liquidado (Pago)", isOn: $isPaid)
                    }
                }

                Section("Classificação") {
                    if type == .expense && !store.creditCards.isEmpty {
                        Picker("Meio de Pagamento", selection: $paymentMethodIsCard) {
                            Text("Conta Bancária").tag(false)
                            Text("Cartão de Crédito").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }

                    if usesCreditCard {
                        Picker("Cartão de Crédito", selection: $selectedCreditCardId) {
                            ForEach(store.creditCards) { card in
                                HStack {
                                    Image(systemName: card.iconSymbol)
                                    Text(card.name)
                                }
                                .tag(card.id)
                            }
                        }

                        if let card = selectedCard {
                            let cycle = CreditCardEngine.allocateInvoice(forPurchaseDate: date, card: card, calendar: store.calendar)
                            let dates = CreditCardEngine.closingAndDueDates(forInvoiceYear: cycle.year, month: cycle.month, card: card, calendar: store.calendar)
                            let available = store.availableLimit(for: card.id)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundStyle(Color(hex: "#6366F1"))
                                    Text("Fatura de destino: \(CreditCardEngine.fullInvoiceLabel(year: cycle.year, month: cycle.month, calendar: store.calendar))")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                HStack {
                                    Text("Vencimento em \(AppFormatters.shortDate(dates.dueDate))")
                                    Spacer()
                                    Text("Disp: \(AppFormatters.currency(available))")
                                        .foregroundStyle(available >= (AppFormatters.parseAmount(amountString) ?? 0) ? Color(hex: "#22C55E") : Color(hex: "#F59E0B"))
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        Picker("Conta Bancária", selection: $selectedAccountId) {
                            ForEach(store.accounts) { acc in
                                HStack {
                                    Image(systemName: acc.iconSymbol)
                                    Text(acc.name)
                                }
                                .tag(acc.id)
                            }
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
                        if usesCreditCard {
                            HStack(spacing: 6) {
                                ForEach([2, 3, 6, 10, 12], id: \.self) { count in
                                    Button("\(count)x") {
                                        installmentTotal = count
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(installmentTotal == count ? Color(hex: "#6366F1") : .secondary)
                                }
                            }
                        }

                        Stepper("Parcelas: \(installmentTotal)x", value: $installmentTotal, in: 2...120)

                        if usesCreditCard, let parsedTotal = AppFormatters.parseAmount(amountString), parsedTotal > 0 {
                            let parts = CreditCardEngine.splitInstallmentsExactCents(totalAmount: parsedTotal, count: installmentTotal)
                            if let firstPart = parts.first {
                                Text("\(installmentTotal)x de \(AppFormatters.currency(firstPart)) (divisão exata em centavos nas próximas faturas)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }

                Section("Observações") {
                    TextField("Detalhes adicionais (opcional)", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                }

                if editingTransaction != nil {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Excluir Transação", systemImage: "trash.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingTransaction != nil ? "Editar Lançamento" : "Nova Transação")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Excluir Transação?", isPresented: $showDeleteConfirmation) {
                Button("Excluir", role: .destructive) {
                    if let editing = editingTransaction {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.deleteTransaction(editing.id)
                    }
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Deseja realmente excluir \"\(name)\"? Esta ação não pode ser desfeita.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveTransaction()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (AppFormatters.parseAmount(amountString) ?? 0.0) <= 0.0)
                }
            }
            .onAppear {
                if !store.accounts.contains(where: { $0.id == selectedAccountId }), let firstAcc = store.accounts.first {
                    selectedAccountId = firstAcc.id
                }
                if !store.creditCards.contains(where: { $0.id == selectedCreditCardId }), let firstCard = store.creditCards.first {
                    selectedCreditCardId = firstCard.id
                }
                if !store.categories.contains(where: { $0.id == selectedCategoryId }), let firstCat = store.categories.first(where: { $0.type == type }) ?? store.categories.first {
                    selectedCategoryId = firstCat.id
                }
            }
            .onChange(of: type) { _, newType in
                if newType == .income {
                    paymentMethodIsCard = false
                }
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

        let effectiveCardId: UUID? = usesCreditCard
            ? (store.creditCards.contains(where: { $0.id == selectedCreditCardId }) ? selectedCreditCardId : store.creditCards.first?.id)
            : nil

        let effectiveCategoryId: UUID = store.categories.contains(where: { $0.id == selectedCategoryId })
            ? selectedCategoryId
            : (store.categories.first(where: { $0.type == type })?.id ?? store.categories.first?.id ?? selectedCategoryId)

        if var editing = editingTransaction {
            let wasUnpaid = !editing.isPaid
            editing.name = name
            editing.details = details
            editing.amount = amount
            editing.date = date
            editing.type = type
            editing.categoryId = effectiveCategoryId
            editing.recurrenceMode = recurrenceMode
            if recurrenceMode == .installment {
                editing.installmentTotal = installmentTotal
            }
            if let cardId = effectiveCardId {
                editing.creditCardId = cardId
                editing.accountId = cardId
                editing.isPaid = false
                editing.confirmedRealInterestCorrectionAmount = nil
            } else {
                editing.creditCardId = nil
                editing.creditCardInvoiceYearMonthKey = nil
                editing.creditCardInvoiceId = nil
                editing.accountId = effectiveAccountId
                editing.isPaid = isPaid
                if wasUnpaid && isPaid, let baseReg = editing.baseInstallmentRegisteredAmount, baseReg > 0 {
                    editing.confirmedRealInterestCorrectionAmount = max(0.0, amount - baseReg)
                } else if !isPaid {
                    editing.confirmedRealInterestCorrectionAmount = nil
                }
            }
            store.updateTransaction(editing)
        } else if let cardId = effectiveCardId {
            if recurrenceMode == .installment && type == .expense && installmentTotal > 1 {
                _ = store.createCreditCardInstallments(
                    name: name,
                    details: details,
                    totalAmount: amount,
                    purchaseDate: date,
                    categoryId: effectiveCategoryId,
                    cardId: cardId,
                    installmentsCount: installmentTotal
                )
            } else {
                store.createTransaction(
                    name: name,
                    details: details,
                    amount: amount,
                    date: date,
                    type: .expense,
                    isPaid: false,
                    categoryId: effectiveCategoryId,
                    accountId: cardId,
                    recurrenceMode: recurrenceMode,
                    creditCardId: cardId
                )
            }
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
