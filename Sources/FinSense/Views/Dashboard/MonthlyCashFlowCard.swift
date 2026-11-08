// Sources/FinSense/Views/Dashboard/MonthlyCashFlowCard.swift
import SwiftUI

public struct MonthlyCashFlowCard: View {
    @ObservedObject var store: FinancialDataStore
    public var selectedMonth: Date

    public init(store: FinancialDataStore, selectedMonth: Date) {
        self.store = store
        self.selectedMonth = selectedMonth
    }

    public var body: some View {
        let income = store.monthlyIncome(for: selectedMonth)
        let expense = store.monthlyExpense(for: selectedMonth)
        let pending = store.monthlyPendingExpenses(for: selectedMonth)
        let totalExpensesProjected = expense + pending
        let projectedNet = income - totalExpensesProjected

        LiquidGlassCard(cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Fluxo do Mês")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)

                    Spacer()

                    Text(AppFormatters.monthYear(selectedMonth))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                // Barra Comparativa Gradiente
                GeometryReader { geo in
                    let total = max(income, totalExpensesProjected, 1.0)
                    let incomeWidth = (income / total) * geo.size.width
                    let expenseWidth = (totalExpensesProjected / total) * geo.size.width

                    VStack(spacing: 6) {
                        // Receitas Bar
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 8)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#10B981"), Color(hex: "#059669")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, incomeWidth), height: 8)
                        }

                        // Despesas Bar
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 8)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#F43F5E"), Color(hex: "#DC2626")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, expenseWidth), height: 8)
                        }
                    }
                }
                .frame(height: 24)

                // Grid de Valores
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "#10B981")).frame(width: 6, height: 6)
                            Text("Receitas")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                        Text(AppFormatters.currency(income))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "#DC2626")).frame(width: 6, height: 6)
                            Text("Pagas")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                        Text(AppFormatters.currency(expense))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "#F59E0B")).frame(width: 6, height: 6)
                            Text("Pendentes")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                        Text(AppFormatters.currency(pending))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider().opacity(0.4)

                HStack {
                    Text("Projeção de Sobra Líquida")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)

                    Spacer()

                    Text(AppFormatters.currency(projectedNet))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(projectedNet >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                }
            }
        }
    }
}
