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
    @ObservedObject var aiService: CloudAIService

    @State private var selectedFilter: TransactionFilterTab = .all
    @State private var searchText: String = ""
    @State private var isAddSheetPresented: Bool = false
    @State private var editingTransaction: FinancialTransaction? = nil
    @State private var isCameraScannerPresented: Bool = false
    @State private var parsedFromOCR: ParsedTransactionDTO? = nil
    @State private var isParsingReceiptAlert: Bool = false

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        aiService: CloudAIService
    ) {
        self.store = store
        self.syncService = syncService
        self.aiService = aiService
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
                        subtitle: AppFormatters.monthYear(store.selectedMonth),
                        trailingIcon: "camera.viewfinder"
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isCameraScannerPresented = true
                    }

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
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                    .padding(.horizontal, 20)

                    // Lista Agrupada por Dia
                    if filteredGroupedDays.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 38))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                            Text("Nenhum lançamento encontrado")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text("Toque no botão '+' abaixo para cadastrar uma transação.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal, 30)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredGroupedDays, id: \.date) { group in
                                Section {
                                    ForEach(group.transactions) { tx in
                                        TransactionRow(
                                            transaction: tx,
                                            store: store,
                                            onTap: {
                                                editingTransaction = tx
                                            }
                                        )
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                store.toggleTransactionPaid(transactionId: tx.id)
                                            } label: {
                                                Label(
                                                    tx.isPaid ? "Pendente" : "Pagar",
                                                    systemImage: tx.isPaid ? "clock.fill" : "checkmark.circle.fill"
                                                )
                                            }
                                            .tint(tx.isPaid ? Color(hex: "#F59E0B") : Color(hex: "#10B981"))
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                store.deleteTransaction(tx.id)
                                            } label: {
                                                Label("Excluir", systemImage: "trash.fill")
                                            }

                                            Button {
                                                editingTransaction = tx
                                            } label: {
                                                Label("Editar", systemImage: "pencil")
                                            }
                                            .tint(Color(hex: "#0284C7"))
                                        }
                                    }
                                } header: {
                                    HStack {
                                        Text(AppFormatters.dayGroupHeader(group.date))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.secondary)

                                        Spacer()

                                        Text(AppFormatters.currency(group.netAmount))
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(group.netAmount >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    // Espaço para a TabBar flutuante
                    Color.clear.frame(height: 60)
                }

                // Botão Flutuante de Adicionar Nova Transação
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            isAddSheetPresented = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .background(Circle().fill(Color(hex: "#0284C7")))
                                .shadow(color: Color(hex: "#0284C7").opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 22)
                        .padding(.bottom, 72)
                    }
                }

                // Overlay de Carregamento durante OCR de Recibo
                if aiService.isParsingReceipt {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.4)
                            Text("Processando recibo com IA...")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                TransactionDetailSheet(store: store, syncService: syncService)
            }
            .sheet(item: $editingTransaction) { tx in
                TransactionDetailSheet(store: store, syncService: syncService, editingTransaction: tx)
            }
            .sheet(isPresented: $isCameraScannerPresented) {
                ReceiptCameraScannerView(
                    onImageCaptured: { image in
                        isCameraScannerPresented = false
                        processCapturedReceipt(image)
                    },
                    onCancel: {
                        isCameraScannerPresented = false
                    }
                )
            }
            .sheet(item: $parsedFromOCR) { parsed in
                TransactionDetailSheet(store: store, syncService: syncService, prefilledParsed: parsed)
            }
        }
    }

    private func processCapturedReceipt(_ image: UIImage) {
        Task {
            do {
                let transactions = try await aiService.parseReceiptImage(image: image, baseURL: syncService.baseURLString)
                if let first = transactions.first {
                    parsedFromOCR = first
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
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
