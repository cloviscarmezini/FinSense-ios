// Sources/FinSense/Views/Dashboard/AccountsCarouselView.swift
import SwiftUI

public struct AccountsCarouselView: View {
    @ObservedObject var store: FinancialDataStore
    public var onAddAccount: () -> Void

    public init(store: FinancialDataStore, onAddAccount: @escaping () -> Void) {
        self.store = store
        self.onAddAccount = onAddAccount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Minhas Contas")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isHideBalancesEnabled.toggle()
                    }
                } label: {
                    Image(systemName: store.isHideBalancesEnabled ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onAddAccount) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "#0284C7"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            if store.accounts.isEmpty {
                Button(action: onAddAccount) {
                    LiquidGlassCard(cornerRadius: 18, padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.system(size: 24))
                                .foregroundStyle(Color(hex: "#0284C7"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nenhuma conta cadastrada")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Text("Toque para adicionar sua primeira conta")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.accounts) { account in
                            let balance = store.accountBalance(for: account.id)
                            LiquidGlassCard(cornerRadius: 18, padding: 14) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: account.colorHex).opacity(0.18))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: account.iconSymbol)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color(hex: account.colorHex))
                                        }

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(account.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.primary)
                                                .lineLimit(1)

                                            if let preset = BrazilianBanksCatalog.preset(for: account.bankPresetId) {
                                                Text(preset.name)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Saldo Disponível")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Color.secondary)

                                        if store.isHideBalancesEnabled {
                                            Text("••••••")
                                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                                .foregroundStyle(Color.primary)
                                        } else {
                                            Text(AppFormatters.currency(balance))
                                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                                .foregroundStyle(balance >= 0 ? Color.primary : Color(hex: "#EF4444"))
                                        }
                                    }
                                }
                                .frame(width: 150)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
