// Sources/FinSense/Services/CreditCardEngine.swift
import Foundation

/// Motor determinístico e exato de ciclo de faturamento, alocação de faturas, cálculo de limites
/// e divisão monetária sem perda de centavos para Cartões de Crédito no FinSense iOS.
public enum CreditCardEngine {

    public struct AllocatedInvoiceCycle: Hashable, Sendable {
        public let year: Int
        public let month: Int
        public let yearMonthKey: Int
        public let closingDate: Date
        public let dueDate: Date
    }

    public static func suggestedBestPurchaseDay(forClosingDay closingDay: Int) -> Int {
        let clamped = min(max(closingDay, 1), 31)
        return clamped >= 31 ? 1 : (clamped + 1)
    }

    public static func daysInMonth(year: Int, month: Int, calendar: Calendar = .current) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 28
        }
        return range.count
    }

    public static func clampedDate(year: Int, month: Int, day: Int, calendar: Calendar = .current) -> Date {
        let maxDay = daysInMonth(year: year, month: month, calendar: calendar)
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = min(max(day, 1), maxDay)
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? Date()
    }

    public static func addMonths(_ offsetMonths: Int, toYear year: Int, month: Int) -> (year: Int, month: Int, yearMonthKey: Int) {
        let totalMonths = (year * 12 + (month - 1)) + offsetMonths
        let resolvedYear = totalMonths >= 0 ? (totalMonths / 12) : ((totalMonths - 11) / 12)
        let resolvedMonth = ((totalMonths % 12) + 12) % 12 + 1
        return (resolvedYear, resolvedMonth, resolvedYear * 100 + resolvedMonth)
    }

    public static func yearMonthComponents(fromKey key: Int) -> (year: Int, month: Int) {
        let year = key / 100
        let month = max(1, min(12, key % 100))
        return (year, month)
    }

    public static func allocateInvoice(
        forPurchaseDate purchaseDate: Date,
        card: CreditCard,
        calendar: Calendar = .current
    ) -> AllocatedInvoiceCycle {
        let comps = calendar.dateComponents([.year, .month, .day], from: purchaseDate)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1

        let dim = daysInMonth(year: y, month: m, calendar: calendar)
        let effectiveClosingDay = min(card.closingDay, dim)

        let rollsToNextClosingMonth: Bool
        if card.bestPurchaseDay > card.closingDay {
            rollsToNextClosingMonth = d >= card.bestPurchaseDay
        } else if card.bestPurchaseDay == card.closingDay {
            rollsToNextClosingMonth = d >= effectiveClosingDay
        } else {
            rollsToNextClosingMonth = d > effectiveClosingDay
        }

        let closingYM = rollsToNextClosingMonth ? addMonths(1, toYear: y, month: m) : (year: y, month: m, yearMonthKey: y * 100 + m)
        let dueYM = card.dueDay > card.closingDay
            ? closingYM
            : addMonths(1, toYear: closingYM.year, month: closingYM.month)

        let dates = closingAndDueDates(forInvoiceYear: dueYM.year, month: dueYM.month, card: card, calendar: calendar)
        return AllocatedInvoiceCycle(
            year: dueYM.year,
            month: dueYM.month,
            yearMonthKey: dueYM.yearMonthKey,
            closingDate: dates.closingDate,
            dueDate: dates.dueDate
        )
    }

    public static func closingAndDueDates(
        forInvoiceYear year: Int,
        month: Int,
        card: CreditCard,
        calendar: Calendar = .current
    ) -> (closingDate: Date, dueDate: Date) {
        let closingYM = card.dueDay > card.closingDay
            ? (year: year, month: month, yearMonthKey: year * 100 + month)
            : addMonths(-1, toYear: year, month: month)
        let closingDate = clampedDate(year: closingYM.year, month: closingYM.month, day: card.closingDay, calendar: calendar)
        let dueDate = clampedDate(year: year, month: month, day: card.dueDay, calendar: calendar)
        return (closingDate, dueDate)
    }

    public static func invoiceStatus(
        isPaid: Bool,
        invoiceYear: Int,
        invoiceMonth: Int,
        card: CreditCard,
        referenceNow: Date = Date(),
        calendar: Calendar = .current
    ) -> CreditCardInvoiceStatus {
        if isPaid { return .paid }
        let dates = closingAndDueDates(forInvoiceYear: invoiceYear, month: invoiceMonth, card: card, calendar: calendar)
        let todayStart = calendar.startOfDay(for: referenceNow)
        let closingStart = calendar.startOfDay(for: dates.closingDate)
        return todayStart >= closingStart ? .closed : .open
    }

    public static func splitInstallmentsExactCents(totalAmount: Double, count: Int) -> [Double] {
        let safeCount = max(1, count)
        let totalCents = Int64((abs(totalAmount) * 100.0).rounded())
        let baseCents = totalCents / Int64(safeCount)
        let remainder = Int(totalCents % Int64(safeCount))
        var result: [Double] = []
        result.reserveCapacity(safeCount)
        for i in 0..<safeCount {
            let cents = baseCents + (i < remainder ? 1 : 0)
            result.append(Double(cents) / 100.0)
        }
        return result
    }

    public static func exactSum(_ values: [Double]) -> Double {
        let cents = values.reduce(Int64(0)) { acc, val in
            acc + Int64((val * 100.0).rounded())
        }
        return Double(cents) / 100.0
    }

    public static func shortInvoiceLabel(year: Int, month: Int, calendar: Calendar = .current) -> String {
        let d = clampedDate(year: year, month: month, day: 15, calendar: calendar)
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "MMM/yy"
        return df.string(from: d).capitalized
    }

    public static func fullInvoiceLabel(year: Int, month: Int, calendar: Calendar = .current) -> String {
        let d = clampedDate(year: year, month: month, day: 15, calendar: calendar)
        return AppFormatters.monthYear(d)
    }
}
