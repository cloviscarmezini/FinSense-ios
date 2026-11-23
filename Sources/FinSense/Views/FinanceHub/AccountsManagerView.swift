// Sources/FinSense/Views/FinanceHub/AccountsManagerView.swift
import SwiftUI

public struct AccountsManagerView: View {
    @ObservedObject var store: FinancialDataStore
    public var syncService: CloudSyncService? = nil

    @State private var isAddPresented: Bool = false
    @State private var isAddCardPresented: Bool = false
    @State private var editingAccount: BankAccount? = nil
    @State private var editingCard: CreditCard? = nil

    public init(store: FinancialDataStore, syncService: CloudSyncService? = nil) {
        self.store = store
        self.syncService = syncService
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            List {
                Section {
                    ForEach(store.accounts) { account in
                        let currentBalance = store.accountBalance(for: account.id)
                        Button {
                            editingAccount = account
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: account.colorHex).opacity(0.18))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: account.iconSymbol)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color(hex: account.colorHex))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(account.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.primary)

                                    if !account.accountNumber.isEmpty {
                                        Text("Ag: \(account.agency) • CC: \(account.accountNumber)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(AppFormatters.currency(currentBalance))
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundStyle(currentBalance >= 0 ? Color.primary : Color(hex: "#EF4444"))

                                    Text("Inicial: \(AppFormatters.currency(account.initialBalance))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                store.deleteAccount(account.id)
                            } label: {
                                Label("Excluir", systemImage: "trash.fill")
                            }
                        }
                    }
                } header: {
                    Text("Contas Cadastradas (\(store.accounts.count))")
                }

                Section {
                    if store.creditCards.isEmpty {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isAddCardPresented = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#6366F1").opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "creditcard.fill")
                                        .foregroundStyle(Color(hex: "#6366F1"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Adicionar Cartão de Crédito")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Compras no regime de competência e faturas automáticas")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color(hex: "#6366F1"))
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(store.creditCards) { card in
                            let used = store.usedLimit(for: card.id)
                            let available = store.availableLimit(for: card.id)

                            Button {
                                editingCard = card
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: card.colorHex).opacity(0.2))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: card.iconSymbol)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color(hex: card.colorHex))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.name)
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("\(card.brand.rawValue) • Fecha dia \(card.closingDay) • Vence dia \(card.dueDay)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(AppFormatters.currency(available))
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundStyle(available >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))

                                        Text("Usado: \(AppFormatters.currency(used))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    store.deleteCreditCard(card.id)
                                } label: {
                                    Label("Excluir", systemImage: "trash.fill")
                                }
                            }
                        }

                        if let syncService {
                            NavigationLink {
                                CreditCardsManagerView(store: store, syncService: syncService)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundStyle(Color(hex: "#6366F1"))
                                    Text("Ver Faturas e Limites")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Cartões de Crédito (\(store.creditCards.count))")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Contas & Cartões")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isAddPresented = true
                    } label: {
                        Label("Nova Conta Bancária", systemImage: "building.columns.fill")
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isAddCardPresented = true
                    } label: {
                        Label("Novo Cartão de Crédito", systemImage: "creditcard.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            AccountEditorSheet(store: store)
        }
        .sheet(isPresented: $isAddCardPresented) {
            CreditCardEditorSheet(store: store)
        }
        .sheet(item: $editingAccount) { account in
            AccountEditorSheet(store: store, editingAccount: account)
        }
        .sheet(item: $editingCard) { card in
            CreditCardEditorSheet(store: store, existingCard: card)
        }
    }
}

public struct AccountEditorSheet: View {
    public enum CreationType: String, CaseIterable, Identifiable {
        case bankAccount = "Conta Bancária"
        case creditCard = "Cartão de Crédito"
        public var id: String { rawValue }
    }

    @ObservedObject var store: FinancialDataStore
    public var editingAccount: BankAccount?
    @Environment(\.dismiss) var dismiss

    @State private var creationType: CreationType = .bankAccount
    @State private var name: String = ""
    @State private var selectedPresetId: String? = nil
    @State private var initialBalanceString: String = ""
    @State private var agency: String = ""
    @State private var accountNumber: String = ""
    @State private var iconSymbol: String = "building.columns.fill"
    @State private var colorHex: String = "#EC7000"

    // Credit Card creation fields
    @State private var cardLimitString: String = ""
    @State private var cardClosingDay: Int = 10
    @State private var cardBestPurchaseDay: Int = 11
    @State private var cardDueDay: Int = 17
    @State private var cardBestDayCustomized: Bool = false
    @State private var cardBrand: CreditCardBrand = .mastercard
    @State private var cardDefaultPaymentAccountId: UUID? = nil
    @State private var cardLastFourDigits: String = ""

    public init(store: FinancialDataStore, editingAccount: BankAccount? = nil) {
        self.store = store
        self.editingAccount = editingAccount

        if let acc = editingAccount {
            _name = State(initialValue: acc.name)
            _selectedPresetId = State(initialValue: acc.bankPresetId)
            _initialBalanceString = State(initialValue: AppFormatters.currency(acc.initialBalance))
            _agency = State(initialValue: acc.agency)
            _accountNumber = State(initialValue: acc.accountNumber)
            _iconSymbol = State(initialValue: acc.iconSymbol)
            _colorHex = State(initialValue: acc.colorHex)
        } else {
            _cardDefaultPaymentAccountId = State(initialValue: store.accounts.first?.id)
        }
    }

    private var isCreditCardCreation: Bool {
        editingAccount == nil && creationType == .creditCard
    }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isCreditCardCreation {
            return hasName && (AppFormatters.parseAmount(cardLimitString) ?? 0.0) > 0.0
        }
        return hasName
    }

    public var body: some View {
        NavigationStack {
            Form {
                if editingAccount == nil {
                    Section("Tipo de Cadastro") {
                        Picker("Tipo", selection: $creationType) {
                            ForEach(CreationType.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: creationType) { _, newType in
                            if newType == .creditCard && selectedPresetId == nil {
                                iconSymbol = "creditcard.fill"
                                colorHex = "#6366F1"
                            } else if newType == .bankAccount && selectedPresetId == nil {
                                iconSymbol = "building.columns.fill"
                                colorHex = "#EC7000"
                            }
                        }
                    }
                }

                Section(isCreditCardCreation ? "Banco / Emissor" : "Predefinição de Banco") {
                    Picker("Banco ou Carteira", selection: $selectedPresetId) {
                        Text("Personalizado").tag(Optional<String>.none)
                        ForEach(BrazilianBanksCatalog.presets) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }
                    .onChange(of: selectedPresetId) { _, newId in
                        if let preset = BrazilianBanksCatalog.preset(for: newId) {
                            name = preset.name
                            iconSymbol = isCreditCardCreation ? "creditcard.fill" : preset.symbolName
                            colorHex = preset.primaryHex
                        }
                    }
                }

                if isCreditCardCreation {
                    Section("Dados do Cartão") {
                        TextField("Nome do Cartão (ex: Cartão Principal)", text: $name)

                        HStack {
                            Text("Limite Total")
                            Spacer()
                            BRLCurrencyTextField("R$ 0,00", text: $cardLimitString)
                        }

                        Picker("Bandeira", selection: $cardBrand) {
                            ForEach(CreditCardBrand.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }

                        TextField("Últimos 4 dígitos (opcional)", text: $cardLastFourDigits)
                            .keyboardType(.numberPad)
                    }

                    Section("Ciclo da Fatura") {
                        Stepper("Fechamento: dia \(cardClosingDay)", value: $cardClosingDay, in: 1...31)
                            .onChange(of: cardClosingDay) { _, newDay in
                                if !cardBestDayCustomized {
                                    cardBestPurchaseDay = newDay >= 28 ? 1 : (newDay + 1)
                                }
                            }
                        Stepper("Melhor compra: dia \(cardBestPurchaseDay)", value: $cardBestPurchaseDay, in: 1...31)
                            .onChange(of: cardBestPurchaseDay) { _, _ in
                                cardBestDayCustomized = true
                            }
                        Stepper("Vencimento: dia \(cardDueDay)", value: $cardDueDay, in: 1...31)

                        Picker("Conta padrão p/ fatura", selection: $cardDefaultPaymentAccountId) {
                            Text("Nenhuma").tag(Optional<UUID>.none)
                            ForEach(store.accounts) { acc in
                                Text(acc.name).tag(Optional(acc.id))
                            }
                        }
                    }
                } else {
                    Section("Dados da Conta") {
                        TextField("Nome da Conta", text: $name)

                        HStack {
                            Text("Saldo Inicial")
                            Spacer()
                            BRLCurrencyTextField("R$ 0,00", text: $initialBalanceString)
                        }

                        TextField("Agência (opcional)", text: $agency)
                            .keyboardType(.numberPad)

                        TextField("Número da Conta (opcional)", text: $accountNumber)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Personalização Visual") {
                    HStack {
                        Text("Cor")
                        Spacer()
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .navigationTitle(editingAccount != nil ? "Editar Conta" : (isCreditCardCreation ? "Novo Cartão" : "Nova Conta"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        if isCreditCardCreation {
            let limit = AppFormatters.parseAmount(cardLimitString) ?? 0.0
            let digits = String(cardLastFourDigits.filter(\.isNumber).prefix(4))
            _ = store.addCreditCard(
                name: name,
                totalLimit: limit,
                closingDay: cardClosingDay,
                bestPurchaseDay: cardBestPurchaseDay,
                dueDay: cardDueDay,
                defaultPaymentAccountId: cardDefaultPaymentAccountId,
                brand: cardBrand,
                bankPresetId: selectedPresetId,
                iconSymbol: "creditcard.fill",
                colorHex: colorHex,
                lastFourDigits: digits
            )
            dismiss()
            return
        }

        let balance = AppFormatters.parseAmount(initialBalanceString) ?? 0.0
        if var editing = editingAccount {
            editing.name = name
            editing.bankPresetId = selectedPresetId
            editing.initialBalance = balance
            editing.agency = agency
            editing.accountNumber = accountNumber
            editing.iconSymbol = iconSymbol
            editing.colorHex = colorHex
            store.updateAccount(editing)
        } else {
            store.createAccount(
                name: name,
                bankPresetId: selectedPresetId,
                iconSymbol: iconSymbol,
                colorHex: colorHex,
                initialBalance: balance,
                agency: agency,
                accountNumber: accountNumber
            )
        }
        dismiss()
    }
}
