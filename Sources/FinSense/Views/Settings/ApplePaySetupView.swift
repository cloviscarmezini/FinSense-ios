// Sources/FinSense/Views/Settings/ApplePaySetupView.swift
import SwiftUI
import UIKit

public struct ApplePaySetupView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var coordinator: ApplePayAutomationCoordinator = .shared

    @State private var newWalletCardName: String = ""
    @State private var selectedTargetKind: Int = 0 // 0 = Cartão, 1 = Conta
    @State private var selectedCardId: UUID? = nil
    @State private var selectedAccountId: UUID? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    guideSection
                    mappingSection
                    fallbackSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Automação Apple Pay")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedCardId == nil {
                selectedCardId = store.creditCards.first?.id
            }
            if selectedAccountId == nil {
                selectedAccountId = store.accounts.first?.id
            }
        }
    }

    private var guideSection: some View {
        LiquidGlassCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "#10B981"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Como configurar em 3 passos")
                            .font(.system(size: 16, weight: .bold))
                        Text("Capture suas compras da Apple Wallet automaticamente.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.35)

                VStack(alignment: .leading, spacing: 8) {
                    stepRow(number: "1", text: "Abra o app Atalhos (Shortcuts) e toque na aba Automação → \"+\" → Transação.")
                    stepRow(number: "2", text: "Selecione todos os cartões desejados, marque \"Executar Imediatamente\" e avance.")
                    stepRow(number: "3", text: "Adicione a ação \"Registrar Compra Apple Pay\" do FinSense vinculando Valor, Estabelecimento e Cartão.")
                }

                Button {
                    if let url = URL(string: "shortcuts://create-automation") {
                        UIApplication.shared.open(url) { ok in
                            if !ok, let fallback = URL(string: "shortcuts://") {
                                UIApplication.shared.open(fallback)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Abrir App Atalhos")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#0284C7")))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .heavy))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(hex: "#10B981").opacity(0.22)))
                .foregroundStyle(Color(hex: "#10B981"))
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mappingSection: some View {
        LiquidGlassCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("De-Para de Cartões da Apple Wallet")
                    .font(.system(size: 15, weight: .bold))

                Text("Mapeie o nome exato que o iOS informa na Wallet (ex.: \"Nubank Mastercard\") para um cartão ou conta do FinSense.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                TextField("Nome na Apple Wallet (ex: Itaú Visa 1234)", text: $newWalletCardName)
                    .textFieldStyle(.roundedBorder)

                Picker("Tipo de Destino", selection: $selectedTargetKind) {
                    Text("Cartão de Crédito").tag(0)
                    Text("Conta Corrente").tag(1)
                }
                .pickerStyle(.segmented)

                if selectedTargetKind == 0 {
                    if store.creditCards.isEmpty {
                        Text("Nenhum cartão cadastrado no FinSense.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Cartão FinSense", selection: $selectedCardId) {
                            ForEach(store.creditCards) { card in
                                Text(card.name).tag(Optional(card.id))
                            }
                        }
                    }
                } else {
                    if store.accounts.isEmpty {
                        Text("Nenhuma conta cadastrada no FinSense.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Conta FinSense", selection: $selectedAccountId) {
                            ForEach(store.accounts) { acc in
                                Text(acc.name).tag(Optional(acc.id))
                            }
                        }
                    }
                }

                Button {
                    coordinator.addOrUpdateAlias(
                        walletCardName: newWalletCardName,
                        targetCreditCardId: selectedTargetKind == 0 ? selectedCardId : nil,
                        targetAccountId: selectedTargetKind == 1 ? selectedAccountId : nil
                    )
                    newWalletCardName = ""
                } label: {
                    Text("Salvar Mapeamento")
                        .font(.system(size: 13.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#10B981")))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(newWalletCardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !coordinator.configuration.aliases.isEmpty {
                    Divider().opacity(0.35)
                    ForEach(coordinator.configuration.aliases) { alias in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alias.walletCardName)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(resolvedTargetLabel(for: alias))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                coordinator.removeAlias(id: alias.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Color(hex: "#EF4444"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func resolvedTargetLabel(for alias: ApplePayCardAlias) -> String {
        if let cid = alias.targetCreditCardId, let card = store.creditCards.first(where: { $0.id == cid }) {
            return "Cartão: \(card.name)"
        }
        if let aid = alias.targetAccountId, let acc = store.accounts.first(where: { $0.id == aid }) {
            return "Conta: \(acc.name)"
        }
        return "Destino padrão"
    }

    private var fallbackSection: some View {
        LiquidGlassCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Destino Padrão (Fallback)")
                    .font(.system(size: 15, weight: .bold))

                Toggle("Priorizar Cartão de Crédito quando não houver match", isOn: $coordinator.configuration.preferCreditCardFallback)
                    .font(.system(size: 13))

                if !store.creditCards.isEmpty {
                    Picker("Cartão Padrão", selection: $coordinator.configuration.defaultCreditCardId) {
                        Text("Automático (Primeiro Cartão)").tag(Optional<UUID>.none)
                        ForEach(store.creditCards) { card in
                            Text(card.name).tag(Optional(card.id))
                        }
                    }
                }

                if !store.accounts.isEmpty {
                    Picker("Conta Padrão (Débito)", selection: $coordinator.configuration.defaultAccountId) {
                        Text("Automático (Primeira Conta)").tag(Optional<UUID>.none)
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(Optional(acc.id))
                        }
                    }
                }
            }
        }
    }
}
