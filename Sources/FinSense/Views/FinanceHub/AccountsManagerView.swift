// Sources/FinSense/Views/FinanceHub/AccountsManagerView.swift
import SwiftUI

public struct AccountsManagerView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var isAddPresented: Bool = false
    @State private var editingAccount: BankAccount? = nil

    public init(store: FinancialDataStore) {
        self.store = store
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
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Contas Bancárias")
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
            AccountEditorSheet(store: store)
        }
        .sheet(item: $editingAccount) { account in
            AccountEditorSheet(store: store, editingAccount: account)
        }
    }
}

public struct AccountEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    public var editingAccount: BankAccount?
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var selectedPresetId: String? = nil
    @State private var initialBalanceString: String = ""
    @State private var agency: String = ""
    @State private var accountNumber: String = ""
    @State private var iconSymbol: String = "building.columns.fill"
    @State private var colorHex: String = "#EC7000"

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
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Predefinição de Banco") {
                    Picker("Banco ou Carteira", selection: $selectedPresetId) {
                        Text("Personalizado").tag(Optional<String>.none)
                        ForEach(BrazilianBanksCatalog.presets) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }
                    .onChange(of: selectedPresetId) { _, newId in
                        if let preset = BrazilianBanksCatalog.preset(for: newId) {
                            name = preset.name
                            iconSymbol = preset.symbolName
                            colorHex = preset.primaryHex
                        }
                    }
                }

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
            .navigationTitle(editingAccount != nil ? "Editar Conta" : "Nova Conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
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
