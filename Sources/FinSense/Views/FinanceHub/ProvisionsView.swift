// Sources/FinSense/Views/FinanceHub/ProvisionsView.swift
import SwiftUI

public enum ProvisionsTab: String, CaseIterable, Identifiable {
    case ceilings = "Tetos por Categoria"
    case quotas = "Cotas do Mês"

    public var id: String { rawValue }
}

public struct ProvisionsView: View {
    @ObservedObject var store: FinancialDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ProvisionsTab = .ceilings
    @State private var isMonthPickerPresented: Bool = false
    @State private var editingProvisionCategory: CategoryItem? = nil
    @State private var isAddProvisionPresented: Bool = false
    @State private var isAddQuotaPresented: Bool = false
    @State private var redeemingQuotaEnvelope: CategoryQuotaEnvelope? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        let provisionEnvelopes = store.calculateProvisionEnvelopes(for: store.selectedMonth)
        let quotaEnvelopes = store.calculateQuotaEnvelopes(for: store.selectedMonth)

        let totalEstimated = store.totalEstimatedProvision(for: store.selectedMonth)
        let totalRemaining = store.totalRemainingProvision(for: store.selectedMonth)
        let totalRealized = max(0.0, totalEstimated - totalRemaining)

        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
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
                            .foregroundStyle(Color(hex: "#6366F1"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(hex: "#6366F1").opacity(0.12)))
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
                                    .foregroundStyle(Color(hex: "#6366F1"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color(hex: "#6366F1").opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Card Resumo Orçamentário
                    LiquidGlassCard(cornerRadius: 20, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Resumo do Mês")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(provisionEnvelopes.count) teto(s) • \(quotaEnvelopes.count) cota(s)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Total Orçado")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.secondary)
                                    Text(AppFormatters.currency(totalEstimated))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Divider().frame(height: 24).opacity(0.4)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Consumido")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.secondary)
                                    Text(AppFormatters.currency(totalRealized))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#EF4444"))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Divider().frame(height: 24).opacity(0.4)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Restante")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.secondary)
                                    Text(AppFormatters.currency(totalRemaining))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#6366F1"))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Segmented Control de Abas
                    HStack(spacing: 8) {
                        ForEach(ProvisionsTab.allCases) { tab in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedTab = tab
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                                    let count = tab == .ceilings ? provisionEnvelopes.count : quotaEnvelopes.count
                                    Text("(\(count))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .opacity(0.8)
                                }
                                .foregroundStyle(selectedTab == tab ? .white : Color.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background {
                                    if selectedTab == tab {
                                        Capsule()
                                            .fill(Color(hex: "#6366F1"))
                                    } else {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Conteúdo por Aba
                    if selectedTab == .ceilings {
                        ceilingsSection(envelopes: provisionEnvelopes)
                    } else {
                        quotasSection(envelopes: quotaEnvelopes)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Previsões & Tetos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if selectedTab == .ceilings {
                        isAddProvisionPresented = true
                    } else {
                        isAddQuotaPresented = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .sheet(isPresented: $isMonthPickerPresented) {
            MonthPickerSheet(selectedMonth: $store.selectedMonth)
        }
        .sheet(item: $editingProvisionCategory) { cat in
            ProvisionEditorSheet(store: store, category: cat)
        }
        .sheet(isPresented: $isAddProvisionPresented) {
            ProvisionEditorSheet(store: store, category: nil)
        }
        .sheet(isPresented: $isAddQuotaPresented) {
            QuotaEditorSheet(store: store)
        }
        .sheet(item: $redeemingQuotaEnvelope) { env in
            RedeemQuotaSheet(store: store, envelope: env)
        }
    }

    // MARK: - Seção de Tetos por Categoria
    @ViewBuilder
    private func ceilingsSection(envelopes: [CategoryProvisionEnvelope]) -> some View {
        if envelopes.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                Text("Nenhum teto configurado para este mês")
                    .font(.system(size: 15, weight: .bold))
                Text("Defina tetos de gastos para suas categorias (ex: Alimentação, Lazer) e acompanhe o orçamento.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    isAddProvisionPresented = true
                } label: {
                    Text("Definir Novo Teto")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(hex: "#6366F1")))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.top, 40)
            .padding(.horizontal, 30)
        } else {
            VStack(spacing: 12) {
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

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(env.category.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.primary)
                                        if env.isInheritedFromPreviousMonth {
                                            Text("Recorrente de mês anterior")
                                                .font(.system(size: 9.5))
                                                .foregroundStyle(Color.secondary)
                                        }
                                    }

                                    Spacer()

                                    Text(env.statusTitle)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color(hex: env.statusColorHex).opacity(0.15)))
                                        .foregroundStyle(Color(hex: env.statusColorHex))
                                }

                                // Barra de Progresso
                                GeometryReader { geo in
                                    let ratio = min(1.0, env.estimatedAmount > 0 ? (env.realizedExpense / env.estimatedAmount) : 0.0)
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.primary.opacity(0.08))
                                            .frame(height: 7)
                                        Capsule()
                                            .fill(Color(hex: env.statusColorHex))
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
        }
    }

    // MARK: - Seção de Cotas do Mês
    @ViewBuilder
    private func quotasSection(envelopes: [CategoryQuotaEnvelope]) -> some View {
        if envelopes.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                Text("Nenhuma cota cadastrada para este mês")
                    .font(.system(size: 15, weight: .bold))
                Text("Cadastre cotas recorrentes como Gás, Faxina, Delivery ou Galões de Água.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    isAddQuotaPresented = true
                } label: {
                    Text("Cadastrar Nova Cota")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(hex: "#0284C7")))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.top, 40)
            .padding(.horizontal, 30)
        } else {
            VStack(spacing: 12) {
                ForEach(envelopes) { env in
                    let isInvestment = env.quotaType == .investment
                    let accentColorHex = isInvestment ? "#10B981" : "#0284C7"

                    LiquidGlassCard(cornerRadius: 18, padding: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: accentColorHex).opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: isInvestment ? "chart.line.uptrend.xyaxis" : env.iconSymbol)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color(hex: accentColorHex))
                                }

                                VStack(alignment: .leading, spacing: 1) {
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
                                         ? (env.consumedUnits >= env.plannedQuantity && env.plannedQuantity > 0
                                            ? "\(env.consumedUnits) de \(env.plannedQuantity) aportes • Meta concluída"
                                            : "\(env.consumedUnits) de \(env.plannedQuantity) aportes • \(AppFormatters.currency(env.remainingProvision)) restantes")
                                         : "\(env.consumedUnits) de \(env.plannedQuantity) consumidas • \(AppFormatters.currency(env.remainingProvision)) restantes")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }

                                Spacer()

                                Text(env.statusTitle)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color(hex: env.statusColorHex).opacity(0.15)))
                                    .foregroundStyle(Color(hex: env.statusColorHex))
                            }

                            // Barra de Consumo de Cotas
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(height: 7)
                                    Capsule()
                                        .fill(Color(hex: env.statusColorHex))
                                        .frame(width: max(7, CGFloat(env.progressRatio) * geo.size.width), height: 7)
                                }
                            }
                            .frame(height: 7)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isInvestment ? "Total Planejado: \(AppFormatters.currency(env.totalEstimatedAmount))" : "Unitário: \(AppFormatters.currency(env.estimatedUnitPrice))")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(Color.secondary)
                                    if !isInvestment {
                                        Text("Total: \(AppFormatters.currency(env.totalEstimatedAmount))")
                                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.primary)
                                    }
                                }

                                Spacer()

                                Button {
                                    redeemingQuotaEnvelope = env
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isInvestment ? "arrow.up.circle.fill" : "cart.badge.plus")
                                        Text(isInvestment ? "Aportar" : "Baixar Cota")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color(hex: isInvestment ? "#10B981" : "#0284C7")))
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
}

// MARK: - ProvisionEditorSheet

public struct ProvisionEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    public let category: CategoryItem?
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategoryId: UUID
    @State private var amountString: String = ""
    @State private var repeatForFuture: Bool = true
    @State private var showDeleteConfirmation: Bool = false

    public init(store: FinancialDataStore, category: CategoryItem? = nil) {
        self.store = store
        self.category = category

        let initialCatId: UUID
        if let category {
            initialCatId = category.id
        } else if let firstExpense = store.categories.first(where: { $0.type == .expense }) {
            initialCatId = firstExpense.id
        } else {
            initialCatId = UUID()
        }
        _selectedCategoryId = State(initialValue: initialCatId)

        let cal = store.calendar
        let year = cal.component(.year, from: store.selectedMonth)
        let month = cal.component(.month, from: store.selectedMonth)
        let existing = store.provisions.first(where: { $0.categoryId == initialCatId && $0.year == year && $0.month == month })
        let initialAmount = existing != nil ? AppFormatters.currency(existing!.estimatedAmount) : ""
        _amountString = State(initialValue: initialAmount)
        _repeatForFuture = State(initialValue: existing?.repeatForFutureMonths ?? true)
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let cat = category {
                    Section("Categoria") {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: cat.colorHex).opacity(0.18))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: cat.iconSymbol)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(hex: cat.colorHex))
                                )
                            Text(cat.name)
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                } else {
                    Section("Selecionar Categoria") {
                        Picker("Categoria", selection: $selectedCategoryId) {
                            ForEach(store.categories.filter { $0.type == .expense }) { cat in
                                Text(cat.name).tag(cat.id)
                            }
                        }
                    }
                }

                Section("Teto Mensal") {
                    HStack {
                        Text("Valor Previsto")
                        Spacer()
                        BRLCurrencyTextField("R$ 0,00", text: $amountString)
                    }

                    Toggle("Repetir para os próximos meses", isOn: $repeatForFuture)
                }

                if category != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Excluir Teto de Gastos")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("Definir Meta de Teto")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Excluir Teto: \(category?.name ?? "")",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                let catId = category?.id ?? selectedCategoryId
                Button("Excluir somente deste mês") {
                    store.deleteCategoryProvision(categoryId: catId, for: store.selectedMonth, scope: .onlyThisMonth)
                    dismiss()
                }
                Button("Excluir deste mês em diante") {
                    store.deleteCategoryProvision(categoryId: catId, for: store.selectedMonth, scope: .fromThisMonthOnward)
                    dismiss()
                }
                Button("Excluir todas as ocorrências", role: .destructive) {
                    store.deleteCategoryProvision(categoryId: catId, for: store.selectedMonth, scope: .allOccurrences)
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Deseja remover o teto desta categoria somente deste mês, deste mês em diante (preservando o histórico anterior) ou excluir todas as ocorrências?")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let amount = AppFormatters.parseAmount(amountString) ?? 0.0
                        let cal = store.calendar
                        let year = cal.component(.year, from: store.selectedMonth)
                        let month = cal.component(.month, from: store.selectedMonth)
                        let catId = category?.id ?? selectedCategoryId

                        store.setProvision(categoryId: catId, year: year, month: month, amount: amount, repeatForFuture: repeatForFuture)
                        dismiss()
                    }
                }
            }
        }
    }
}
