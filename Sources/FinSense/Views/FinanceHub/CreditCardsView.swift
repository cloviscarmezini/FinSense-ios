// Sources/FinSense/Views/FinanceHub/CreditCardsView.swift
import SwiftUI

public struct CreditCardsManagerView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService

    @State private var selectedCardId: UUID?
    @State private var selectedMonthKey: Int = {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.year, from: now) * 100 + cal.component(.month, from: now)
    }()

    @State private var isAddCardPresented: Bool = false
    @State private var editingCard: CreditCard? = nil
    @State private var cardPendingDelete: CreditCard? = nil

    @State private var isNewPurchasePresented: Bool = false
    @State private var editingTransaction: FinancialTransaction? = nil
    @State private var payingSummary: CreditCardInvoiceSummary? = nil

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        initialCardId: UUID? = nil
    ) {
        self.store = store
        self.syncService = syncService
        _selectedCardId = State(initialValue: initialCardId)
    }

    private var activeCard: CreditCard? {
        if let id = selectedCardId, let found = store.creditCard(for: id) {
            return found
        }
        return store.creditCards.first
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if store.creditCards.isEmpty {
                        emptyStateView
                    } else {
                        cardSelectorStrip

                        if let card = activeCard {
                            cardLimitHeroCard(card)
                            invoiceBrowserSection(for: card)
                        }
                    }

                    Color.clear.frame(height: 60)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle("Cartões de Crédito")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isAddCardPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            syncSelection()
        }
        .sheet(isPresented: $isAddCardPresented) {
            CreditCardEditorSheet(store: store, existingCard: nil) { created in
                selectedCardId = created.id
                syncSelection(resetMonth: true)
            }
        }
        .sheet(item: $editingCard) { card in
            CreditCardEditorSheet(store: store, existingCard: card)
        }
        .sheet(item: $payingSummary) { summary in
            if let card = store.creditCard(for: summary.cardId) {
                PayCreditCardInvoiceIOSSheet(store: store, card: card, summary: summary)
            }
        }
        .sheet(isPresented: $isNewPurchasePresented) {
            TransactionDetailSheet(
                store: store,
                syncService: syncService,
                editingTransaction: nil,
                initialCreditCardId: activeCard?.id
            )
        }
        .sheet(item: $editingTransaction) { tx in
            TransactionDetailSheet(store: store, syncService: syncService, editingTransaction: tx)
        }
        .confirmationDialog(
            "Excluir Cartão?",
            isPresented: Binding(
                get: { cardPendingDelete != nil },
                set: { if !$0 { cardPendingDelete = nil } }
            ),
            presenting: cardPendingDelete
        ) { card in
            Button("Excluir Cartão", role: .destructive) {
                store.deleteCreditCard(card.id)
                cardPendingDelete = nil
                syncSelection(resetMonth: true)
            }
            Button("Cancelar", role: .cancel) {
                cardPendingDelete = nil
            }
        } message: { card in
            Text("O cartão \"\(card.name)\" será removido. Projeções de faturas em aberto serão canceladas.")
        }
    }

    private func syncSelection(resetMonth: Bool = false) {
        if selectedCardId == nil || store.creditCard(for: selectedCardId) == nil {
            selectedCardId = store.creditCards.first?.id
        }
        guard let card = activeCard else { return }
        let months = store.allRelevantInvoiceMonths(for: card.id)
        if resetMonth || !months.contains(where: { $0.key == selectedMonthKey }) {
            let allocKey = CreditCardEngine.allocateInvoice(forPurchaseDate: Date(), card: card).yearMonthKey
            if months.contains(where: { $0.key == allocKey }) {
                selectedMonthKey = allocKey
            } else if let first = months.first {
                selectedMonthKey = first.key
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        LiquidGlassCard(cornerRadius: 22, padding: 24) {
            VStack(spacing: 14) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color(hex: "#820AD1"))

                Text("Nenhum Cartão Cadastrado")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text("Cadastre seus cartões de crédito para acompanhar limites, fechar faturas no ciclo correto e evitar contagem dupla entre Competência e Caixa.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    isAddCardPresented = true
                } label: {
                    Label("Cadastrar Cartão", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(hex: "#820AD1")))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Card Selector Strip

    private var cardSelectorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.creditCards) { card in
                    let isSelected = card.id == activeCard?.id
                    let available = store.availableLimit(for: card.id)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedCardId = card.id
                        syncSelection(resetMonth: true)
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: card.colorHex).opacity(0.22))
                                    .frame(width: 36, height: 36)
                                Image(systemName: card.iconSymbol)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color(hex: card.colorHex))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                Text("Disp: \(AppFormatters.currency(available))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isSelected ? Color(hex: card.colorHex) : Color.white.opacity(0.14), lineWidth: isSelected ? 1.8 : 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Hero Limit Card

    private func cardLimitHeroCard(_ card: CreditCard) -> some View {
        let used = store.usedLimit(for: card.id)
        let available = store.availableLimit(for: card.id)
        let ratio = card.totalLimit > 0 ? min(1.0, max(0.0, used / card.totalLimit)) : 0.0
        let defaultBankName = store.account(for: card.defaultPaymentAccountId)?.name ?? "Automática"

        return LiquidGlassCard(cornerRadius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: card.colorHex).opacity(0.22))
                            .frame(width: 48, height: 48)
                        Image(systemName: card.iconSymbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(hex: card.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(card.name)
                                .font(.system(size: 17, weight: .bold))
                            Text(card.brand.shortBadge)
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: card.colorHex).opacity(0.20)))
                                .foregroundStyle(Color(hex: card.colorHex))
                        }

                        Text("Fecha \(card.closingDay) • Melhor compra \(card.bestPurchaseDay) • Vence \(card.dueDay)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)

                        Text("Débito fatura: \(defaultBankName)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Menu {
                        Button {
                            editingCard = card
                        } label: {
                            Label("Editar Cartão", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            cardPendingDelete = card
                        } label: {
                            Label("Excluir Cartão", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.secondary)
                    }
                }

                ProgressView(value: ratio)
                    .tint(used > card.totalLimit ? Color(hex: "#EF4444") : Color(hex: card.colorHex))

                HStack(spacing: 10) {
                    metricCol(title: "Limite Total", value: AppFormatters.currency(card.totalLimit), color: .primary)
                    metricCol(title: "Utilizado", value: AppFormatters.currency(used), color: used > 0 ? Color(hex: "#F59E0B") : .secondary)
                    metricCol(title: "Disponível", value: AppFormatters.currency(available), color: available > 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isNewPurchasePresented = true
                } label: {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                        Text("Lançar Compra neste Cartão")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: card.colorHex)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func metricCol(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Invoice Browser & Transactions

    private func invoiceBrowserSection(for card: CreditCard) -> some View {
        let months = store.allRelevantInvoiceMonths(for: card.id)
        let comps = CreditCardEngine.yearMonthComponents(fromKey: selectedMonthKey)
        let summary = store.invoiceSummary(for: card.id, year: comps.year, month: comps.month)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Faturas (Histórico, Atual e Parcelas Futuras)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(months, id: \.key) { item in
                        let invSum = store.invoiceSummary(for: card.id, year: item.year, month: item.month)
                        let isSelected = item.key == selectedMonthKey
                        let statusColor = Color(hex: invSum?.status.colorHex ?? CreditCardInvoiceStatus.open.colorHex)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedMonthKey = item.key
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(CreditCardEngine.shortInvoiceLabel(year: item.year, month: item.month))
                                        .font(.system(size: 12, weight: .bold))
                                    Circle()
                                        .fill(statusColor)
                                        .frame(width: 6, height: 6)
                                }
                                Text(AppFormatters.currency(invSum?.totalAmount ?? 0))
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? statusColor.opacity(0.18) : Color.primary.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? statusColor : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 0.8)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }

            if let summary {
                invoiceDetailCard(card: card, summary: summary)
            }
        }
    }

    private func invoiceDetailCard(card: CreditCard, summary: CreditCardInvoiceSummary) -> some View {
        let statusColor = Color(hex: summary.status.colorHex)
        let payAccountName = store.account(for: summary.paymentAccountId)?.name ?? "Conta principal"

        return LiquidGlassCard(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Fatura \(summary.monthYearLabel)")
                                .font(.system(size: 16, weight: .bold))
                            Text(summary.status.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(statusColor.opacity(0.18)))
                                .foregroundStyle(statusColor)
                        }
                        Text("Fechamento: \(AppFormatters.shortDate(summary.closingDate)) • Vence: \(AppFormatters.shortDate(summary.dueDate))")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                        Text("Débito previsto: \(payAccountName)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                        Text(AppFormatters.currency(summary.totalAmount))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(summary.status == .paid ? Color(hex: "#10B981") : Color.primary)
                    }
                }

                if summary.status != .paid && summary.totalAmount > 0.001 {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        payingSummary = summary
                    } label: {
                        Label("Pagar Fatura", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#10B981")))
                    }
                    .buttonStyle(.plain)
                } else if summary.status == .paid, let paidDate = summary.paidDate {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Paga em \(AppFormatters.shortDate(paidDate)) via \(payAccountName)")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#10B981"))
                }

                Divider()

                if summary.transactions.isEmpty {
                    Text("Nenhuma compra lançada neste ciclo.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(summary.transactions) { tx in
                            let cat = store.category(for: tx.categoryId)
                            Button {
                                editingTransaction = tx
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: cat?.colorHex ?? "#6366F1").opacity(0.18))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: cat?.iconSymbol ?? "tag.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color(hex: cat?.colorHex ?? "#6366F1"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tx.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)
                                        HStack(spacing: 5) {
                                            Text(AppFormatters.shortDate(tx.date))
                                            if let cat {
                                                Text("• \(cat.name)")
                                            }
                                            if let badge = tx.installmentBadge {
                                                Text("• \(badge)")
                                            }
                                        }
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(Color.secondary)
                                    }

                                    Spacer()

                                    Text(AppFormatters.currency(tx.amount))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.primary)
                                }
                                .padding(.vertical, 4)
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

// MARK: - Credit Card Editor Sheet (Create & Edit)

public struct CreditCardEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    public var existingCard: CreditCard?
    public var onCreated: ((CreditCard) -> Void)?
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var totalLimitString: String = ""
    @State private var closingDay: Int = 25
    @State private var bestPurchaseDay: Int = 26
    @State private var bestPurchaseManuallyEdited: Bool = false
    @State private var dueDay: Int = 5
    @State private var defaultPaymentAccountId: UUID? = nil
    @State private var brand: CreditCardBrand = .mastercard
    @State private var selectedPresetId: String? = "nubank"
    @State private var colorHex: String = "#820AD1"
    @State private var lastFourDigits: String = ""

    public init(store: FinancialDataStore, existingCard: CreditCard? = nil, onCreated: ((CreditCard) -> Void)? = nil) {
        self.store = store
        self.existingCard = existingCard
        self.onCreated = onCreated
        if let card = existingCard {
            _name = State(initialValue: card.name)
            _totalLimitString = State(initialValue: AppFormatters.currency(card.totalLimit))
            _closingDay = State(initialValue: card.closingDay)
            _bestPurchaseDay = State(initialValue: card.bestPurchaseDay)
            _bestPurchaseManuallyEdited = State(initialValue: card.bestPurchaseDay != CreditCardEngine.suggestedBestPurchaseDay(forClosingDay: card.closingDay))
            _dueDay = State(initialValue: card.dueDay)
            _defaultPaymentAccountId = State(initialValue: card.defaultPaymentAccountId)
            _brand = State(initialValue: card.brand)
            _selectedPresetId = State(initialValue: card.bankPresetId)
            _colorHex = State(initialValue: card.colorHex)
            _lastFourDigits = State(initialValue: card.lastFourDigits)
        } else {
            _defaultPaymentAccountId = State(initialValue: store.accounts.first?.id)
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identidade e Limite") {
                    Picker("Banco Emissor (Opcional)", selection: $selectedPresetId) {
                        Text("Personalizado").tag(Optional<String>.none)
                        ForEach(BrazilianBanksCatalog.presets) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }
                    .onChange(of: selectedPresetId) { _, newId in
                        if let preset = BrazilianBanksCatalog.preset(for: newId) {
                            colorHex = preset.primaryHex
                            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                                name = "Cartão \(preset.name)"
                            }
                        }
                    }

                    TextField("Nome do Cartão (ex: Cartão Principal)", text: $name)

                    HStack {
                        Text("Limite Total")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $totalLimitString)
                    }

                    Picker("Bandeira", selection: $brand) {
                        ForEach(CreditCardBrand.allCases) { b in
                            Text(b.rawValue).tag(b)
                        }
                    }

                    TextField("Últimos 4 dígitos (opcional)", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFourDigits) { _, newVal in
                            let clean = String(newVal.filter(\.isNumber).prefix(4))
                            if clean != newVal { lastFourDigits = clean }
                        }
                }

                Section("Datas da Fatura") {
                    Stepper("Fechamento: dia \(closingDay)", value: $closingDay, in: 1...31)
                        .onChange(of: closingDay) { _, newClosing in
                            if !bestPurchaseManuallyEdited {
                                bestPurchaseDay = CreditCardEngine.suggestedBestPurchaseDay(forClosingDay: newClosing)
                            }
                        }

                    Stepper("Melhor dia de compra: \(bestPurchaseDay)", value: $bestPurchaseDay, in: 1...31)
                        .onChange(of: bestPurchaseDay) { _, newBest in
                            if newBest != CreditCardEngine.suggestedBestPurchaseDay(forClosingDay: closingDay) {
                                bestPurchaseManuallyEdited = true
                            }
                        }

                    Stepper("Vencimento: dia \(dueDay)", value: $dueDay, in: 1...31)

                    Picker("Conta para Pagamento", selection: $defaultPaymentAccountId) {
                        Text("Conta principal automática").tag(Optional<UUID>.none)
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(Optional(acc.id))
                        }
                    }
                }
            }
            .navigationTitle(existingCard == nil ? "Novo Cartão" : "Editar Cartão")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveCard()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (AppFormatters.parseAmount(totalLimitString) ?? 0.0) <= 0.0)
                }
            }
        }
    }

    private func saveCard() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let limit = AppFormatters.parseAmount(totalLimitString), limit > 0 else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if var card = existingCard {
            card.name = trimmed
            card.totalLimit = limit
            card.closingDay = closingDay
            card.bestPurchaseDay = bestPurchaseDay
            card.dueDay = dueDay
            card.defaultPaymentAccountId = defaultPaymentAccountId
            card.brand = brand
            card.bankPresetId = selectedPresetId
            card.colorHex = colorHex
            card.lastFourDigits = lastFourDigits
            store.updateCreditCard(card)
        } else {
            let created = store.addCreditCard(
                name: trimmed,
                totalLimit: limit,
                closingDay: closingDay,
                bestPurchaseDay: bestPurchaseDay,
                dueDay: dueDay,
                defaultPaymentAccountId: defaultPaymentAccountId,
                brand: brand,
                bankPresetId: selectedPresetId,
                iconSymbol: "creditcard.fill",
                colorHex: colorHex,
                lastFourDigits: lastFourDigits
            )
            onCreated?(created)
        }
        dismiss()
    }
}

// MARK: - Pay Credit Card Invoice Sheet (iOS)

public struct PayCreditCardInvoiceIOSSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let card: CreditCard
    public let summary: CreditCardInvoiceSummary
    @Environment(\.dismiss) var dismiss

    @State private var selectedAccountId: UUID = UUID()
    @State private var paymentDate: Date = Date()
    @State private var amountText: String = ""

    public init(store: FinancialDataStore, card: CreditCard, summary: CreditCardInvoiceSummary) {
        self.store = store
        self.card = card
        self.summary = summary
        let initialAccId = summary.paymentAccountId ?? card.defaultPaymentAccountId ?? store.accounts.first?.id ?? UUID()
        _selectedAccountId = State(initialValue: initialAccId)
        _paymentDate = State(initialValue: Date())
        _amountText = State(initialValue: AppFormatters.currency(summary.totalAmount))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Fatura") {
                    HStack {
                        Text("Cartão")
                        Spacer()
                        Text(card.name).fontWeight(.semibold)
                    }
                    HStack {
                        Text("Competência")
                        Spacer()
                        Text(summary.monthYearLabel)
                    }
                    HStack {
                        Text("Vencimento")
                        Spacer()
                        Text(AppFormatters.shortDate(summary.dueDate))
                    }
                }

                Section("Dados do Pagamento (Caixa)") {
                    Picker("Conta de Origem", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            Text("\(acc.name) (\(AppFormatters.currency(store.accountBalance(for: acc.id))))").tag(acc.id)
                        }
                    }

                    DatePicker("Data Efetiva", selection: $paymentDate, displayedComponents: .date)

                    HStack {
                        Text("Valor Pago")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $amountText)
                    }
                }

                Section {
                    Text("Ao confirmar, a fatura será marcada como Paga, o débito bancário será efetivado na conta escolhida e o limite do cartão será restabelecido sem duplicar despesas.")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .navigationTitle("Pagar Fatura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        let amt = AppFormatters.parseAmount(amountText) ?? summary.totalAmount
                        guard amt > 0, store.account(for: selectedAccountId) != nil else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let ok = store.payCreditCardInvoice(
                            cardId: card.id,
                            year: summary.year,
                            month: summary.month,
                            fromAccountId: selectedAccountId,
                            amount: amt,
                            paymentDate: paymentDate
                        )
                        if ok { dismiss() }
                    }
                    .disabled(store.accounts.isEmpty || (AppFormatters.parseAmount(amountText) ?? 0) <= 0)
                }
            }
        }
    }
}
