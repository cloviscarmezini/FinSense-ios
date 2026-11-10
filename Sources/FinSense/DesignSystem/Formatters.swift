// Sources/FinSense/DesignSystem/Formatters.swift
import Foundation

public enum AppFormatters {
    public static let currencyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale(identifier: "pt_BR")
        nf.currencySymbol = "R$"
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf
    }()

    public static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "dd/MM/yyyy"
        return df
    }()

    public static let monthYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "MMMM 'de' yyyy"
        return df
    }()

    public static let shortMonthYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "MMM/yy"
        return df
    }()

    public static let weekdayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "EEEE"
        return df
    }()

    public static let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return df
    }()

    public static func dateTime(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    public static func currency(_ value: Double) -> String {
        let raw = currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "R$ %.2f", value)
        return raw.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    public static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    public static func dayGroupHeader(_ date: Date) -> String {
        let datePart = shortDateFormatter.string(from: date)
        let weekdayPart = weekdayFormatter.string(from: date).capitalized
        return "\(datePart) • \(weekdayPart)"
    }

    public static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date).capitalized
    }

    public static func yearString(_ date: Date) -> String {
        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        return String(year)
    }

    public static func parseAmount(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return nil }

        if cleaned.contains(",") && cleaned.contains(".") {
            let normalized = cleaned
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        } else if cleaned.contains(",") {
            let normalized = cleaned.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        } else if cleaned.range(of: #"^-?\d{1,3}(?:\.\d{3})+$"#, options: .regularExpression) != nil {
            let normalized = cleaned.replacingOccurrences(of: ".", with: "")
            return Double(normalized)
        } else {
            return Double(cleaned)
        }
    }

    public static func parseCurrencyInput(_ text: String) -> Double {
        parseAmount(text) ?? 0.0
    }

    public static func formatCurrencyMaskedInput(_ rawText: String) -> String {
        let digitsOnly = rawText.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return "" }
        let trimmedDigits = String(digitsOnly.drop(while: { $0 == "0" }))
        if trimmedDigits.isEmpty {
            return ""
        }
        let safeDigits = String(trimmedDigits.prefix(14))
        guard let cents = UInt64(safeDigits) else { return "" }
        let value = Double(cents) / 100.0
        return currency(value)
    }

    public static func formatDigitsOnly(_ rawText: String, maxDigits: Int = 4) -> String {
        let digits = rawText.filter { $0.isNumber }
        return String(digits.prefix(maxDigits))
    }
}

public typealias BRLFormatters = AppFormatters

