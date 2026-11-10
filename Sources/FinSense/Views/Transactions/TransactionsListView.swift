// Sources/FinSense/Views/Transactions/TransactionsListView.swift
import SwiftUI

public enum TransactionFilterTab: String, CaseIterable, Identifiable {
    case all = "Todos"
    case expenses = "Despesas"
    case incomes = "Receitas"
    case pending = "Pendentes"

    public var id: String { rawValue }
}

public struct TransactionsListView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var authService: AuthService

    @State private var selectedFilter: TransactionFilterTab = .all
    @State private var searchText: String = ""
    @State private var isAddSheetPresented: Bool = false
    @State private var isMonthPickerPresented: Bool = false
    @State private var editingTransaction: FinancialTransaction? = nil

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        authService: AuthService
    ) {
        self.store = store
        self.syncService = syncService
        self.authService = authService
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Header de Navegação
                    LiquidNavigationBar(
                        syncService: syncService,
                        title: "Extrato",
                        subtitle: nil,
                        trailingIcon: "plus"
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isAddSheetPresented = true
                    }

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

                    // Pílulas Deslizantes de Filtro
                    HStack(spacing: 8) {
                        ForEach(TransactionFilterTab.allCases) { tab in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedFilter = tab
                                }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedFilter == tab ? .bold : .medium))
                                    .foregroundStyle(selectedFilter == tab ? .white : Color.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background {
                                        if selectedFilter == tab {
                                            Capsule()
                                                .fill(Color(hex: "#0284C7"))
                                        } else {
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Campo de Busca
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary)

                        TextField("Buscar por nome, conta ou valor...", text: $searchText)
                            .font(.system(size: 14))

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                    )
                    .padding(.horizontal, 20)

                    // Lista de Transações Agrupadas por Dia
                    if filteredGroupedDays.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "tray.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.secondary.opacity(0.4))
                            Text("Nenhuma transação encontrada")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredGroupedDays, id: \.date) { group in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Header do Dia
                                        HStack {
                                            Text(AppFormatters.dayGroupHeader(group.date))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.secondary)

                                            Spacer()

                                            Text(AppFormatters.currency(group.netAmount))
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundStyle(group.netAmount >= 0 ? Color(hex: "#10B981") : Color.secondary)
                                        }
                                        .padding(.horizontal, 24)

                                        // Linhas do Dia
                                        ForEach(group.transactions) { tx in
                                            TransactionRow(
                                                transaction: tx,
                                                store: store,
                                                onTap: {
                                                    editingTransaction = tx
                                                }
                                            )
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 72)
                        }
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                TransactionDetailSheet(store: store, syncService: syncService)
            }
            .sheet(isPresented: $isMonthPickerPresented) {
                MonthPickerSheet(selectedMonth: $store.selectedMonth)
            }
            .sheet(item: $editingTransaction) { tx in
                TransactionDetailSheet(store: store, syncService: syncService, editingTransaction: tx)
            }
        }
    }

    private struct DayGroup {
        let date: Date
        let transactions: [FinancialTransaction]
        var netAmount: Double {
            transactions.reduce(0.0) { $0 + $1.signedAmount }
        }
    }

    private var filteredGroupedDays: [DayGroup] {
        let cal = Calendar.current
        var list = store.transactions(for: store.selectedMonth)

        // Filtro por Segmento
        switch selectedFilter {
        case .all: break
        case .expenses: list = list.filter { $0.type == .expense }
        case .incomes: list = list.filter { $0.type == .income }
        case .pending: list = list.filter { !$0.isPaid }
        }

        // Busca
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.details.lowercased().contains(query) ||
                String(format: "%.2f", $0.amount).contains(query)
            }
        }

        // Agrupamento por dia (normalizado meia-noite)
        let grouped = Dictionary(grouping: list) { tx -> Date in
            cal.startOfDay(for: tx.date)
        }

        return grouped.keys.sorted(by: >).map { date in
            DayGroup(date: date, transactions: grouped[date]!.sorted(by: { $0.date > $1.date }))
        }
    }
}

public struct TransactionRow: View {
    public let transaction: FinancialTransaction
    @ObservedObject public var store: FinancialDataStore
    public var onTap: () -> Void

    public var body: some View {
        Button(action: onTap) {
            let cat = store.categories.first(where: { $0.id == transaction.categoryId })
            let acc = store.accounts.first(where: { $0.id == transaction.accountId })

            LiquidGlassCard(cornerRadius: 16, padding: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: cat?.colorHex ?? "#3B82F6").opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: cat?.iconSymbol ?? "tag.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: cat?.colorHex ?? "#3B82F6"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(transaction.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let acc {
                                Text(acc.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }

                            if let badge = transaction.installmentBadge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                                    .foregroundStyle(Color.secondary)
                            }

                            if !transaction.isPaid {
                                Text("Pendente")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color(hex: "#F59E0B").opacity(0.18)))
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                            }
                        }
                    }

                    Spacer()

                    Text(AppFormatters.currency(transaction.amount))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(transaction.type == .income ? Color(hex: "#10B981") : Color.primary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
