// Sources/FinSense/Views/FinanceHub/CategoriesManagerView.swift
import SwiftUI

public struct CategoriesManagerView: View {
    @ObservedObject var store: FinancialDataStore
    @State private var selectedTab: TransactionType = .expense
    @State private var isAddPresented: Bool = false
    @State private var editingCategory: CategoryItem? = nil

    public init(store: FinancialDataStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Picker("Tipo", selection: $selectedTab) {
                    Text("Despesas").tag(TransactionType.expense)
                    Text("Receitas").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                List {
                    let filtered = store.categories.filter { $0.type == selectedTab }
                    Section {
                        ForEach(filtered) { cat in
                            Button {
                                editingCategory = cat
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: cat.colorHex).opacity(0.18))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: cat.iconSymbol)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color(hex: cat.colorHex))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cat.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.primary)

                                        if !cat.keywords.isEmpty {
                                            Text(cat.keywords.prefix(3).joined(separator: ", "))
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    store.deleteCategory(cat.id)
                                } label: {
                                    Label("Excluir", systemImage: "trash.fill")
                                }
                            }
                        }
                    } header: {
                        Text("\(selectedTab.title) (\(filtered.count))")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Categorias")
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
            CategoryEditorSheet(store: store, defaultType: selectedTab)
        }
        .sheet(item: $editingCategory) { cat in
            CategoryEditorSheet(store: store, editingCategory: cat, defaultType: cat.type)
        }
    }
}

public struct CategoryEditorSheet: View {
    @ObservedObject var store: FinancialDataStore
    public var editingCategory: CategoryItem?
    public var defaultType: TransactionType
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var type: TransactionType = .expense
    @State private var iconSymbol: String = "tag.fill"
    @State private var colorHex: String = "#3B82F6"
    @State private var keywordsText: String = ""

    private let availableIcons = [
        "cart.fill", "fork.knife", "house.fill", "bolt.fill", "wifi",
        "bus.fill", "fuelpump.fill", "gamecontroller.fill", "bag.fill",
        "pawprint.fill", "graduationcap.fill", "cross.case.fill", "scissors",
        "creditcard.fill", "banknote.fill", "chart.line.uptrend.xyaxis",
        "checkmark.shield.fill", "sparkles", "gift.fill", "airplane"
    ]

    private let availableColors = [
        "#F97316", "#EF4444", "#6366F1", "#EAB308", "#06B6D4",
        "#3B82F6", "#0EA5E9", "#A855F7", "#EC4899", "#84CC16",
        "#8B5CF6", "#14B8A6", "#10B981", "#F43F5E", "#DC2626"
    ]

    public init(store: FinancialDataStore, editingCategory: CategoryItem? = nil, defaultType: TransactionType = .expense) {
        self.store = store
        self.editingCategory = editingCategory
        self.defaultType = defaultType

        if let cat = editingCategory {
            _name = State(initialValue: cat.name)
            _type = State(initialValue: cat.type)
            _iconSymbol = State(initialValue: cat.iconSymbol)
            _colorHex = State(initialValue: cat.colorHex)
            _keywordsText = State(initialValue: cat.keywords.joined(separator: ", "))
        } else {
            _type = State(initialValue: defaultType)
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identificação") {
                    Picker("Tipo", selection: $type) {
                        Text("Despesa").tag(TransactionType.expense)
                        Text("Receita").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    TextField("Nome da Categoria", text: $name)
                }

                Section("Ícone SF Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                iconSymbol = icon
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(iconSymbol == icon ? Color(hex: colorHex).opacity(0.3) : Color.primary.opacity(0.06))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(iconSymbol == icon ? Color(hex: colorHex) : Color.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Cor") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(availableColors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: colorHex == hex ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Palavras-chave para Auto-categorização") {
                    TextField("Ex: IFOOD, UBER, MERCADO (separadas por vírgula)", text: $keywordsText)
                }
            }
            .navigationTitle(editingCategory != nil ? "Editar Categoria" : "Nova Categoria")
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
        let keywords = keywordsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }

        if var editing = editingCategory {
            editing.name = name
            editing.type = type
            editing.iconSymbol = iconSymbol
            editing.colorHex = colorHex
            editing.keywords = keywords
            store.updateCategory(editing)
        } else {
            store.createCategory(
                name: name,
                type: type,
                iconSymbol: iconSymbol,
                colorHex: colorHex,
                keywords: keywords
            )
        }
        dismiss()
    }
}
