// Sources/FinSense/Intents/LogApplePayTransactionIntent.swift
import Foundation
import AppIntents

@available(iOS 16.0, *)
public struct LogApplePayTransactionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Registrar Compra Apple Pay"
    public static var description = IntentDescription(
        "Registra automaticamente uma compra feita com Apple Pay no FinSense para revisão e sincronização com o Mac."
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Valor")
    public var amount: Double

    @Parameter(title: "Estabelecimento")
    public var merchant: String

    @Parameter(title: "Cartão na Wallet")
    public var cardName: String?

    @Parameter(title: "Data")
    public var date: Date?

    public init() {}

    public init(amount: Double, merchant: String, cardName: String? = nil, date: Date? = nil) {
        self.amount = amount
        self.merchant = merchant
        self.cardName = cardName
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let tx = await ApplePayAutomationCoordinator.shared.recordApplePayTransaction(
            amount: amount,
            merchant: merchant,
            cardName: cardName,
            date: date ?? Date(),
            triggerBackgroundSync: true
        )

        if let tx {
            let formatted = AppFormatters.currency(tx.amount)
            return .result(dialog: "Compra registrada: \(tx.name) (\(formatted)) marcada para revisão no FinSense.")
        }
        return .result(dialog: "Não foi possível registrar a compra: informe um valor maior que zero.")
    }
}

@available(iOS 16.0, *)
public struct FinSenseShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogApplePayTransactionIntent(),
            phrases: [
                "Registrar compra no \(.applicationName)",
                "Lançar Apple Pay no \(.applicationName)",
                "Registrar pagamento no \(.applicationName)"
            ],
            shortTitle: "Registrar Apple Pay",
            systemImageName: "creditcard.and.123"
        )
    }
}
