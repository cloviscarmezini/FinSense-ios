// Sources/FinSense/Views/FinanceHub/CategoryQuotasView.swift
import SwiftUI

public struct CategoryQuotasView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var isAddQuotaPresented: Bool = false
    @State private var isMonthPickerPresented: Bool = false
    @State private var redeemingEnvelope: CategoryQuotaEnvelope? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        let envelopes = store.calculateQuotaEnvelopes(for: store.selectedMonth)

        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    // Seletor e Navegação de Mês
                    HStack(spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.changeMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(7)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isMonthPickerPresented = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(AppFormatters.monthYear(store.selectedMonth))
                                    .font(.system(size: 13, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: "#0284C7"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.changeMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(7)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if !store.isInMonth(Date(), monthReference: store.selectedMonth) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                store.selectedMonth = Date()
                            } label: {
                                Text("Hoje")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#0284C7"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    if envelopes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                            Text("Nenhuma cota cadastrada")
                                .font(.system(size: 15, weight: .bold))
                            Text("Cadastre cotas recorrentes como Gás, Faxina, Delivery ou Galões de Água.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 30)
                    } else {
                        ForEach(envelopes) { env in
                            LiquidGlassCard(cornerRadius: 18, padding: 14) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: "#0284C7").opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: env.iconSymbol)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(Color(hex: "#0284C7"))
                                        }

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(env.name)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color.primary)
                                            Text("\(env.consumedUnits) de \(env.plannedQuantity) consumidas")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.secondary)
                                        }

                                        Spacer()

                                        Text(env.status.title)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color(hex: env.status.colorHex).opacity(0.15)))
                                            .foregroundStyle(Color(hex: env.status.colorHex))
                                    }

                                    // Barra de Consumo de Cotas
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.primary.opacity(0.08))
                                                .frame(height: 7)
                                            Capsule()
                                                .fill(Color(hex: env.status.colorHex))
                                                .frame(width: max(7, CGFloat(env.progressRatio) * geo.size.width), height: 7)
                                        }
                                    }
                                    .frame(height: 7)

                                    HStack {
                                        Text("Unitário: \(AppFormatters.currency(env.estimatedUnitPrice))")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)

                                        Spacer()

                                        Button {
                                            redeemingEnvelope = env
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "cart.badge.plus")
                                                Text("Baixar Cota")
                                            }
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(Color(hex: "#0284C7")))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .navigationTitle("Cotas por Categoria")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isAddQuotaPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddQuotaPresented) {
            QuotaEditorSheet(store: store)
        }
        .sheet(isPresented: $isMonthPickerPresented) {
            MonthPickerSheet(selectedMonth: $store.selectedMonth)
        }
        .sheet(item: $redeemingEnvelope) { env in
            RedeemQuotaSheet(store: store, envelope: env)
        }
    }
}

public struct QuotaEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var selectedCategoryId: UUID = UUID()
    @State private var plannedQuantity: Int = 4
    @State private var unitPriceString: String = "50,00"
    @State private var repeatForFuture: Bool = true

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identificação da Cota") {
                    TextField("Nome (ex: Botijão de Gás, Faxina quinzenal)", text: $name)

                    Picker("Categoria", selection: $selectedCategoryId) {
                        ForEach(store.categories.filter { $0.type == .expense }) { cat in
                            Text(cat.name).tag(cat.id)
                        }
                    }
                }

                Section("Planejamento Mensal") {
                    Stepper("Quantidade Mensal: \(plannedQuantity)", value: $plannedQuantity, in: 1...100)

                    HStack {
                        Text("Preço Unitário Estimado (R$)")
                        Spacer()
                        TextField("0,00", text: $unitPriceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Repetir para os meses seguintes", isOn: $repeatForFuture)
                }
            }
            .navigationTitle("Nova Cota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let unitPrice = AppFormatters.parseAmount(unitPriceString) ?? 0.0
                        let cal = Calendar.current
                        let year = cal.component(.year, from: store.selectedMonth)
                        let month = cal.component(.month, from: store.selectedMonth)

                        store.createQuota(
                            categoryId: selectedCategoryId,
                            name: name,
                            year: year,
                            month: month,
                            quantity: plannedQuantity,
                            unitPrice: unitPrice,
                            repeatForFuture: repeatForFuture
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let first = store.categories.first(where: { $0.type == .expense }) {
                    selectedCategoryId = first.id
                }
            }
        }
    }
}

public struct RedeemQuotaSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let envelope: CategoryQuotaEnvelope
    @Environment(\.dismiss) var dismiss

    @State private var units: Int = 1
    @State private var selectedAccountId: UUID = UUID()

    public var body: some View {
        NavigationStack {
            Form {
                Section("Baixa de Unidades") {
                    Text("Cota: \(envelope.name)")
                        .bold()

                    Stepper("Unidades a Baixar: \(units)", value: $units, in: 1...10)

                    HStack {
                        Text("Valor Total a Debitar")
                        Spacer()
                        Text(AppFormatters.currency(Double(units) * envelope.estimatedUnitPrice))
                            .bold()
                            .foregroundStyle(Color(hex: "#10B981"))
                    }

                    Picker("Conta de Pagamento", selection: $selectedAccountId) {
                        ForEach(store.accounts) { acc in
                            Text(acc.name).tag(acc.id)
                        }
                    }
                }
            }
            .navigationTitle("Dar Baixa em Cota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar Baixa") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.redeemQuotaUnits(
                            quotaId: envelope.rule.id,
                            units: units,
                            accountId: selectedAccountId
                        )
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
