// Sources/FinSense/Views/FinanceHub/CategoryQuotasView.swift
import SwiftUI

public struct CategoryQuotasView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var isAddQuotaPresented: Bool = false
    @State private var isMonthPickerPresented: Bool = false
    @State private var redeemingEnvelope: CategoryQuotaEnvelope? = nil
    @State private var pendingDeleteQuotaEnvelope: CategoryQuotaEnvelope? = nil
    @State private var showDeleteQuotaConfirmation: Bool = false

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
                                    HStack(spacing: 12) {
                                        let isInvestment = env.quotaType == .investment
                                        let accentColorHex = isInvestment ? "#10B981" : "#0284C7"

                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: accentColorHex).opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: isInvestment ? "chart.line.uptrend.xyaxis" : env.iconSymbol)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(Color(hex: accentColorHex))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(env.name)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(Color.primary)
                                                if isInvestment {
                                                    Text("INVESTIMENTO")
                                                        .font(.system(size: 8.5, weight: .bold))
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1.5)
                                                        .background(Capsule().fill(Color(hex: "#10B981").opacity(0.18)))
                                                        .foregroundStyle(Color(hex: "#10B981"))
                                                }
                                            }
                                            Text(isInvestment
                                                 ? "\(env.consumedUnits) de \(env.plannedQuantity) aportes • \(AppFormatters.currency(env.remainingProvision)) restantes"
                                                 : "\(env.consumedUnits) de \(env.plannedQuantity) consumidas • \(AppFormatters.currency(env.remainingProvision)) restantes")
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
                                        Text(env.quotaType == .investment ? "Total Planejado: \(AppFormatters.currency(env.totalEstimatedAmount))" : "Unitário: \(AppFormatters.currency(env.estimatedUnitPrice))")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)

                                        Spacer()

                                        Button {
                                            redeemingEnvelope = env
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: env.quotaType == .investment ? "arrow.up.circle.fill" : "cart.badge.plus")
                                                Text(env.quotaType == .investment ? "Aportar" : "Baixar Cota")
                                            }
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(Color(hex: env.quotaType == .investment ? "#10B981" : "#0284C7")))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingDeleteQuotaEnvelope = env
                                    showDeleteQuotaConfirmation = true
                                } label: {
                                    Label("Excluir Cota", systemImage: "trash")
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
        .confirmationDialog(
            "Excluir Cota: \(pendingDeleteQuotaEnvelope?.name ?? "")",
            isPresented: $showDeleteQuotaConfirmation,
            titleVisibility: .visible
        ) {
            if let env = pendingDeleteQuotaEnvelope {
                Button("Excluir somente deste mês") {
                    store.deleteCategoryQuota(seriesId: env.seriesId, for: store.selectedMonth, scope: .onlyThisMonth)
                    pendingDeleteQuotaEnvelope = nil
                }
                Button("Excluir deste mês em diante") {
                    store.deleteCategoryQuota(seriesId: env.seriesId, for: store.selectedMonth, scope: .fromThisMonthOnward)
                    pendingDeleteQuotaEnvelope = nil
                }
                Button("Excluir todas as ocorrências", role: .destructive) {
                    store.deleteCategoryQuota(seriesId: env.seriesId, for: store.selectedMonth, scope: .allOccurrences)
                    pendingDeleteQuotaEnvelope = nil
                }
            }
            Button("Cancelar", role: .cancel) {
                pendingDeleteQuotaEnvelope = nil
            }
        } message: {
            Text("Deseja remover esta cota somente deste mês, deste mês em diante (preservando o histórico anterior) ou excluir todas as ocorrências?")
        }
    }
}

public struct QuotaEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    @Environment(\.dismiss) var dismiss

    @State private var quotaType: QuotaType = .expense
    @State private var selectedInvestmentId: UUID = UUID()
    @State private var name: String = ""
    @State private var selectedCategoryId: UUID = UUID()
    @State private var plannedQuantity: Int = 4
    @State private var unitPriceString: String = AppFormatters.currency(50.0)
    @State private var repeatForFuture: Bool = true

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo de Cota", selection: $quotaType) {
                        Text("Cota de Despesa").tag(QuotaType.expense)
                        Text("Planejamento de Investimento").tag(QuotaType.investment)
                    }
                    .pickerStyle(.segmented)
                }

                if quotaType == .investment {
                    Section("Investimento de Destino") {
                        if store.investments.isEmpty {
                            Text("Nenhum investimento cadastrado. Cadastre investimentos na aba Investimentos para vincular.")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#EF4444"))
                        } else {
                            Picker("Investimento", selection: $selectedInvestmentId) {
                                ForEach(store.investments) { inv in
                                    Text("\(inv.name) (\(inv.groupName))").tag(inv.id)
                                }
                            }
                            .onChange(of: selectedInvestmentId) { _, newId in
                                if let inv = store.investments.first(where: { $0.id == newId }) {
                                    if name.isEmpty || store.investments.contains(where: { "Aporte \($0.name)" == name || $0.name == name }) {
                                        name = "Aporte \(inv.name)"
                                    }
                                }
                            }
                        }

                        TextField("Identificação (ex: Aporte Tesouro Direto)", text: $name)
                    }

                    Section("Planejamento de Aporte") {
                        HStack {
                            Text("Valor a Guardar / Investir")
                            Spacer()
                            BRLCurrencyTextField("R$ 0,00", text: $unitPriceString)
                        }

                        Toggle("Repetir para os meses seguintes", isOn: $repeatForFuture)
                    }
                } else {
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
                            Text("Preço Unitário Estimado")
                            Spacer()
                            BRLCurrencyTextField("R$ 0,00", text: $unitPriceString)
                        }

                        Toggle("Repetir para os meses seguintes", isOn: $repeatForFuture)
                    }
                }
            }
            .navigationTitle(quotaType == .investment ? "Novo Planejamento" : "Nova Cota")
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

                        if quotaType == .investment {
                            let inv = store.investments.first(where: { $0.id == selectedInvestmentId })
                            let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? "Aporte \(inv?.name ?? "Investimento")"
                                : name
                            let fallbackCat = store.fallbackCategoryId(for: .expense, matchingSubstring: "Aplicações")

                            store.createQuota(
                                categoryId: fallbackCat,
                                name: finalName,
                                iconSymbol: inv?.iconSymbol ?? "chart.line.uptrend.xyaxis",
                                year: year,
                                month: month,
                                quantity: 1,
                                unitPrice: unitPrice,
                                repeatForFuture: repeatForFuture,
                                quotaType: .investment,
                                linkedInvestmentId: selectedInvestmentId
                            )
                        } else {
                            store.createQuota(
                                categoryId: selectedCategoryId,
                                name: name,
                                iconSymbol: "shippingbox.fill",
                                year: year,
                                month: month,
                                quantity: plannedQuantity,
                                unitPrice: unitPrice,
                                repeatForFuture: repeatForFuture,
                                quotaType: .expense,
                                linkedInvestmentId: nil
                            )
                        }
                        dismiss()
                    }
                    .disabled(quotaType == .investment ? (store.investments.isEmpty || (AppFormatters.parseAmount(unitPriceString) ?? 0.0) <= 0) : name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let first = store.categories.first(where: { $0.type == .expense }) {
                    selectedCategoryId = first.id
                }
                if let firstInv = store.investments.first {
                    selectedInvestmentId = firstInv.id
                    if quotaType == .investment && name.isEmpty {
                        name = "Aporte \(firstInv.name)"
                    }
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
        let isInvestment = envelope.quotaType == .investment
        let investmentName = store.investments.first(where: { $0.id == envelope.linkedInvestmentId })?.name ?? envelope.name

        NavigationStack {
            Form {
                if isInvestment {
                    Section("Planejamento de Investimento") {
                        Text("Aporte: \(envelope.name)")
                            .bold()
                        Text("Investimento de Destino: \(investmentName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Valor a Aportar")
                            Spacer()
                            Text(AppFormatters.currency(envelope.estimatedUnitPrice))
                                .bold()
                                .foregroundStyle(Color(hex: "#10B981"))
                        }

                        Picker("Conta de Pagamento (Saída)", selection: $selectedAccountId) {
                            ForEach(store.accounts) { acc in
                                Text(acc.name).tag(acc.id)
                            }
                        }
                    }
                } else {
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
            }
            .navigationTitle(isInvestment ? "Realizar Aporte" : "Dar Baixa em Cota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isInvestment ? "Confirmar Aporte" : "Confirmar Baixa") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.redeemQuotaUnits(
                            quotaId: envelope.rule.id,
                            units: isInvestment ? 1 : units,
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
