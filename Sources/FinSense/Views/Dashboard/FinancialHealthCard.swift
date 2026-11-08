// Sources/FinSense/Views/Dashboard/FinancialHealthCard.swift
import SwiftUI

public struct FinancialHealthCard: View {
    @ObservedObject var store: FinancialDataStore
    public var selectedMonth: Date

    public init(store: FinancialDataStore, selectedMonth: Date) {
        self.store = store
        self.selectedMonth = selectedMonth
    }

    public var body: some View {
        let score = store.financialHealthScore(for: selectedMonth)
        let income = store.monthlyIncome(for: selectedMonth)
        let expense = store.monthlyExpense(for: selectedMonth)
        let net = store.monthlyNetBalance(for: selectedMonth)

        LiquidGlassCard(cornerRadius: 24, padding: 18) {
            HStack(spacing: 20) {
                // Anel Circular com Gradiente
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 9)
                        .frame(width: 82, height: 82)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(score) / 100.0)
                        .stroke(
                            scoreGradient(for: score),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 82, height: 82)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: score)

                    VStack(spacing: -2) {
                        Text("\(score)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                        Text("/ 100")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Saúde Financeira")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Spacer()

                        Text(scoreLabel(for: score))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(scoreBadgeColor(for: score).opacity(0.15))
                            .foregroundStyle(scoreBadgeColor(for: score))
                            .clipShape(Capsule())
                    }

                    Text(healthInsight(income: income, expense: expense, net: net, score: score))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(3)

                    HStack(spacing: 12) {
                        Label {
                            Text(AppFormatters.currency(net))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(net >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                        } icon: {
                            Image(systemName: net >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(net >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func scoreGradient(for score: Int) -> LinearGradient {
        if score >= 70 {
            return LinearGradient(colors: [Color(hex: "#10B981"), Color(hex: "#059669")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if score >= 40 {
            return LinearGradient(colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color(hex: "#F43F5E"), Color(hex: "#DC2626")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func scoreBadgeColor(for score: Int) -> Color {
        if score >= 70 { return Color(hex: "#10B981") }
        if score >= 40 { return Color(hex: "#F59E0B") }
        return Color(hex: "#F43F5E")
    }

    private func scoreLabel(for score: Int) -> String {
        if score >= 70 { return "Excelente" }
        if score >= 50 { return "Equilibrado" }
        if score >= 40 { return "Atenção" }
        return "Crítico"
    }

    private func healthInsight(income: Double, expense: Double, net: Double, score: Int) -> String {
        if income == 0 && expense == 0 {
            return "Nenhuma movimentação registrada no mês selecionado."
        }
        if net > 0 {
            let pct = income > 0 ? (net / income) * 100 : 0
            return "Você está poupando \(String(format: "%.0f", pct))% da sua receita líquida este mês."
        } else if net < 0 {
            return "Suas despesas superaram suas receitas em \(AppFormatters.currency(abs(net)))."
        } else {
            return "Seu fluxo de caixa está exatamente no ponto de equilíbrio."
        }
    }
}
