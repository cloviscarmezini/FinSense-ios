// Sources/FinSense/Views/Dashboard/IncomeCommitmentDonutCard.swift
import SwiftUI
import Charts

public struct IncomeCommitmentSlice: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let amount: Double
    public let ratio: Double
    public let colorHex: String
    public let iconSymbol: String
    public let order: Int

    public var color: Color {
        Color(hex: colorHex)
    }

    public init(
        id: String,
        title: String,
        amount: Double,
        ratio: Double,
        colorHex: String,
        iconSymbol: String,
        order: Int
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.ratio = ratio
        self.colorHex = colorHex
        self.iconSymbol = iconSymbol
        self.order = order
    }
}

public struct IncomeCommitmentDonutCard: View {
    @ObservedObject public var store: FinancialDataStore
    public var referenceDate: Date
    public var isAnnual: Bool

    public init(
        store: FinancialDataStore,
        referenceDate: Date,
        isAnnual: Bool
    ) {
        self.store = store
        self.referenceDate = referenceDate
        self.isAnnual = isAnnual
    }

    public var body: some View {
        let totalIncome = isAnnual
            ? store.annualIncome(for: referenceDate)
            : store.monthlyIncome(for: referenceDate)

        let totalExpenses = isAnnual
            ? store.annualExpense(for: referenceDate)
            : store.monthlyExpense(for: referenceDate)

        let loanInstallments = store.periodInstallmentsTotal(
            for: .loan,
            referenceDate: referenceDate,
            isAnnual: isAnnual
        )

        let financingInstallments = store.periodInstallmentsTotal(
            for: .financing,
            referenceDate: referenceDate,
            isAnnual: isAnnual
        )

        let debtServiceTotal = loanInstallments + financingInstallments
        let operationalLivingCost = max(0.0, totalExpenses - debtServiceTotal)
        let totalOutflows = debtServiceTotal + operationalLivingCost

        let dtiRatio: Double = totalIncome > 0 ? (debtServiceTotal / totalIncome) : 0.0

        let isDeficit = totalOutflows > totalIncome
        let freeMargin = isDeficit ? 0.0 : (totalIncome - totalOutflows)
        let freeMarginRatio = totalIncome > 0 ? (freeMargin / totalIncome) : 0.0

        let deficitAmount = isDeficit ? (totalOutflows - totalIncome) : 0.0
        let deficitRatio = totalIncome > 0 ? (deficitAmount / totalIncome) : (totalOutflows > 0 ? 1.0 : 0.0)

        let slices = buildSlices(
            totalIncome: totalIncome,
            loanInstallments: loanInstallments,
            financingInstallments: financingInstallments,
            operationalLivingCost: operationalLivingCost,
            freeMargin: freeMargin,
            deficitAmount: deficitAmount,
            isDeficit: isDeficit
        )

        LiquidGlassCard(cornerRadius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                // Header da Seção
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#0284C7"))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Distribuição de Compromissos")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Text(isAnnual ? "Receitas vs. despesas e dívidas no ano" : "Receitas vs. compromissos no mês")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    Spacer()

                    // Badge de DTI Consolidado
                    HStack(spacing: 4) {
                        Text("DTI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(dtiBadgeColor(dti: dtiRatio))
                        Text(totalIncome > 0 ? String(format: "%.1f%%", dtiRatio * 100) : "--")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(dtiBadgeColor(dti: dtiRatio))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(dtiBadgeColor(dti: dtiRatio).opacity(0.14)))
                }

                // Gráfico Donut (Anel Único com Miolo Analítico)
                ZStack {
                    if slices.isEmpty || slices.allSatisfy({ $0.amount <= 0 }) {
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 22)
                            .frame(width: 190, height: 190)
                    } else {
                        Chart(slices) { slice in
                            SectorMark(
                                angle: .value("Montante", slice.amount),
                                innerRadius: .ratio(0.68),
                                angularInset: 2.5
                            )
                            .cornerRadius(3.5)
                            .foregroundStyle(slice.color)
                        }
                        .chartLegend(.hidden)
                        .frame(width: 220, height: 220)
                    }

                    // Indicador Central de Saúde (Miolo)
                    VStack(spacing: 2) {
                        Text(isDeficit ? "Déficit Operacional" : (isAnnual ? "Margem Livre Anual" : "Margem Livre Mensal"))
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(isDeficit ? Color(hex: "#EF4444") : Color.secondary)
                            .lineLimit(1)

                        Text(isDeficit ? "-\(AppFormatters.currency(deficitAmount))" : AppFormatters.currency(freeMargin))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(isDeficit ? Color(hex: "#EF4444") : Color(hex: "#10B981"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(isDeficit ? String(format: "%.1f%% acima da receita", deficitRatio * 100) : String(format: "%.1f%% receita livre", freeMarginRatio * 100))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isDeficit ? Color(hex: "#EF4444").opacity(0.9) : Color(hex: "#10B981").opacity(0.9))
                            .lineLimit(1)

                        Text(totalIncome > 0 ? String(format: "DTI: %.1f%%", dtiRatio * 100) : "DTI: --")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                            .padding(.top, 2)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                Divider().opacity(0.3)

                // Lista de Distribuição Analítica (Empilhamento Vertical Mobile)
                VStack(spacing: 12) {
                    // 1. Parcelas Financiamentos (se ativo)
                    if financingInstallments > 0 || store.activeContracts(for: .financing).count > 0 {
                        distributionRow(
                            title: "Parcelas Financiamentos",
                            amount: financingInstallments,
                            ratio: totalIncome > 0 ? (financingInstallments / totalIncome) : 0.0,
                            colorHex: "#8B5CF6",
                            iconSymbol: "house.fill"
                        )
                    }

                    // 2. Parcelas Empréstimos (se ativo)
                    if loanInstallments > 0 || store.activeContracts(for: .loan).count > 0 {
                        distributionRow(
                            title: "Parcelas Empréstimos",
                            amount: loanInstallments,
                            ratio: totalIncome > 0 ? (loanInstallments / totalIncome) : 0.0,
                            colorHex: "#F59E0B",
                            iconSymbol: "banknote.fill"
                        )
                    }

                    // 3. Custo de Vida Operacional
                    distributionRow(
                        title: "Custo de Vida Operacional",
                        amount: operationalLivingCost,
                        ratio: totalIncome > 0 ? (operationalLivingCost / totalIncome) : 0.0,
                        colorHex: "#0284C7",
                        iconSymbol: "cart.fill"
                    )

                    // 4. Margem Livre ou Déficit
                    if isDeficit {
                        distributionRow(
                            title: "Estouro / Déficit Operacional",
                            amount: deficitAmount,
                            ratio: deficitRatio,
                            colorHex: "#EF4444",
                            iconSymbol: "exclamationmark.triangle.fill",
                            isNegative: true
                        )
                    } else {
                        distributionRow(
                            title: "Margem Livre / Poupança",
                            amount: freeMargin,
                            ratio: freeMarginRatio,
                            colorHex: "#10B981",
                            iconSymbol: "shield.fill"
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isAnnual)
        .animation(.easeInOut(duration: 0.35), value: referenceDate)
    }

    // MARK: - Linha da Lista de Distribuição
    private func distributionRow(
        title: String,
        amount: Double,
        ratio: Double,
        colorHex: String,
        iconSymbol: String,
        isNegative: Bool = false
    ) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: colorHex).opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: iconSymbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: colorHex))
                }

                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 6) {
                    Text(String(format: "%.1f%%", ratio * 100))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.secondary)

                    Text(isNegative ? "-\(AppFormatters.currency(amount))" : AppFormatters.currency(amount))
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isNegative ? Color(hex: "#EF4444") : Color.primary)
                }
            }

            // Barra de Progresso Proporcional
            GeometryReader { geo in
                let clamped = min(1.0, max(0.0, ratio))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 4.5)
                    Capsule()
                        .fill(Color(hex: colorHex))
                        .frame(width: max(4.5, geo.size.width * CGFloat(clamped)), height: 4.5)
                }
            }
            .frame(height: 4.5)
        }
    }

    // MARK: - Construção das Fatias Contíguas
    private func buildSlices(
        totalIncome: Double,
        loanInstallments: Double,
        financingInstallments: Double,
        operationalLivingCost: Double,
        freeMargin: Double,
        deficitAmount: Double,
        isDeficit: Bool
    ) -> [IncomeCommitmentSlice] {
        var list: [IncomeCommitmentSlice] = []
        let base = max(totalIncome, (loanInstallments + financingInstallments + operationalLivingCost), 1.0)

        // 1. Empréstimos (Laranja)
        if loanInstallments > 0.01 {
            list.append(
                IncomeCommitmentSlice(
                    id: "loans",
                    title: "Parcelas Empréstimos",
                    amount: loanInstallments,
                    ratio: totalIncome > 0 ? (loanInstallments / totalIncome) : (loanInstallments / base),
                    colorHex: "#F59E0B",
                    iconSymbol: "banknote.fill",
                    order: 1
                )
            )
        }

        // 2. Financiamentos (Roxo/Terracota contíguo ao Laranja para visual unificado de DTI)
        if financingInstallments > 0.01 {
            list.append(
                IncomeCommitmentSlice(
                    id: "financings",
                    title: "Parcelas Financiamentos",
                    amount: financingInstallments,
                    ratio: totalIncome > 0 ? (financingInstallments / totalIncome) : (financingInstallments / base),
                    colorHex: "#8B5CF6",
                    iconSymbol: "house.fill",
                    order: 2
                )
            )
        }

        // 3. Custo de Vida Operacional (Azul)
        if operationalLivingCost > 0.01 {
            list.append(
                IncomeCommitmentSlice(
                    id: "living",
                    title: "Custo de Vida Operacional",
                    amount: operationalLivingCost,
                    ratio: totalIncome > 0 ? (operationalLivingCost / totalIncome) : (operationalLivingCost / base),
                    colorHex: "#0284C7",
                    iconSymbol: "cart.fill",
                    order: 3
                )
            )
        }

        // 4. Margem Livre / Poupança (Verde) ou Estouro / Déficit (Vermelho)
        if isDeficit && deficitAmount > 0.01 {
            list.append(
                IncomeCommitmentSlice(
                    id: "deficit",
                    title: "Estouro / Déficit Operacional",
                    amount: deficitAmount,
                    ratio: totalIncome > 0 ? (deficitAmount / totalIncome) : 1.0,
                    colorHex: "#EF4444",
                    iconSymbol: "exclamationmark.triangle.fill",
                    order: 4
                )
            )
        } else if freeMargin > 0.01 {
            list.append(
                IncomeCommitmentSlice(
                    id: "savings",
                    title: "Margem Livre / Poupança",
                    amount: freeMargin,
                    ratio: totalIncome > 0 ? (freeMargin / totalIncome) : 0.0,
                    colorHex: "#10B981",
                    iconSymbol: "shield.fill",
                    order: 4
                )
            )
        }

        return list.sorted { $0.order < $1.order }
    }

    private func dtiBadgeColor(dti: Double) -> Color {
        if dti >= 0.5 {
            return Color(hex: "#EF4444")
        } else if dti >= 0.35 {
            return Color(hex: "#F59E0B")
        } else {
            return Color(hex: "#10B981")
        }
    }
}
