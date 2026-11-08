// Sources/FinSense/Views/FinanceHub/ProvisionsView.swift
import SwiftUI

public struct ProvisionsView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var editingProvisionCategory: CategoryItem? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        let envelopes = store.calculateProvisionEnvelopes(for: store.selectedMonth)

        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text("Mês: \(AppFormatters.monthYear(store.selectedMonth))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    ForEach(envelopes) { env in
                        Button {
                            editingProvisionCategory = env.category
                        } label: {
                            LiquidGlassCard(cornerRadius: 18, padding: 14) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: env.category.colorHex).opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: env.category.iconSymbol)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(Color(hex: env.category.colorHex))
                                        }

                                        Text(env.category.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.primary)

                                        Spacer()

                                        Text(env.status.title)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color(hex: env.status.colorHex).opacity(0.15)))
                                            .foregroundStyle(Color(hex: env.status.colorHex))
                                    }

                                    // Barra de Progresso
                                    GeometryReader { geo in
                                        let ratio = min(1.0, env.estimatedAmount > 0 ? (env.realizedExpense / env.estimatedAmount) : 0.0)
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.primary.opacity(0.08))
                                                .frame(height: 7)
                                            Capsule()
                                                .fill(Color(hex: env.status.colorHex))
                                                .frame(width: max(7, CGFloat(ratio) * geo.size.width), height: 7)
                                        }
                                    }
                                    .frame(height: 7)

                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Gasto Real")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Color.secondary)
                                            Text(AppFormatters.currency(env.realizedExpense))
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("Teto Mensal")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Color.secondary)
                                            Text(AppFormatters.currency(env.estimatedAmount))
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Metas & Provisões")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingProvisionCategory) { cat in
            ProvisionEditorSheet(store: store, category: cat)
        }
    }
}

public struct ProvisionEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let category: CategoryItem
    @Environment(\.dismiss) var dismiss

    @State private var amountString: String = ""
    @State private var repeatForFuture: Bool = true

    public init(store: FinancialDataStore, category: CategoryItem) {
        self.store = store
        self.category = category
        let cal = Calendar.current
        let year = cal.component(.year, from: store.selectedMonth)
        let month = cal.component(.month, from: store.selectedMonth)
        let existing = store.provisions.first(where: { $0.categoryId == category.id && $0.year == year && $0.month == month })
        _amountString = State(initialValue: existing != nil ? String(format: "%.2f", existing!.estimatedAmount) : "0,00")
        _repeatForFuture = State(initialValue: existing?.repeatForFutureMonths ?? true)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Teto Mensal para \(category.name)") {
                    HStack {
                        Text("Valor Previsto (R$)")
                        Spacer()
                        TextField("0,00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Repetir para os próximos meses", isOn: $repeatForFuture)
                }
            }
            .navigationTitle("Definir Meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let amount = AppFormatters.parseAmount(amountString) ?? 0.0
                        let cal = Calendar.current
                        let year = cal.component(.year, from: store.selectedMonth)
                        let month = cal.component(.month, from: store.selectedMonth)
                        store.setProvision(categoryId: category.id, year: year, month: month, amount: amount, repeatForFuture: repeatForFuture)
                        dismiss()
                    }
                }
            }
        }
    }
}
