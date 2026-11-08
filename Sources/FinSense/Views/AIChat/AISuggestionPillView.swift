// Sources/FinSense/Views/AIChat/AISuggestionPillView.swift
import SwiftUI

public struct AISuggestionPillView: View {
    public var onSelectPrompt: (String) -> Void

    public static let suggestedPrompts = [
        "Como quitar meu financiamento imobiliário no menor prazo?",
        "Em quanto tempo consigo quitar o Cartão de Crédito?",
        "Analise meu padrão de gastos deste mês.",
        "Qual é minha capacidade de poupança atual?",
        "Vale a pena amortizar pelo SAC ou PRICE?"
    ]

    public init(onSelectPrompt: @escaping (String) -> Void) {
        self.onSelectPrompt = onSelectPrompt
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.suggestedPrompts, id: \.self) { prompt in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelectPrompt(prompt)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#0284C7"))
                            Text(prompt)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}
