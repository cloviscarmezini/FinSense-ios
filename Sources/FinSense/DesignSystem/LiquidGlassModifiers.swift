// Sources/FinSense/DesignSystem/LiquidGlassModifiers.swift
import SwiftUI

public struct LiquidGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    public var cornerRadius: CGFloat
    public var padding: CGFloat

    public init(cornerRadius: CGFloat = 22, padding: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.25) : Color.white.opacity(0.8), location: 0.0),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.2), location: 0.6),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.5), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.06),
                radius: 16,
                x: 0,
                y: 8
            )
    }
}

public struct LiquidGlassPillModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.white.opacity(0.3) : Color.white.opacity(0.8),
                                colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func liquidGlassPill() -> some View {
        self.modifier(LiquidGlassPillModifier())
    }
}

public struct LiquidGlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        cornerRadius: CGFloat = 22,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .liquidGlassCard(cornerRadius: cornerRadius, padding: padding)
    }
}

// MARK: - Reusable Liquid Glass KPI Card (Strict Vertical Alignment for Mobile Grids)

public struct LiquidKPICard: View {
    public let title: String
    public let value: String
    public var valueColor: Color? = nil
    public let subtitle: String
    public var customSubtitle: Text? = nil
    public let icon: String
    public let tint: Color
    public var footnote: String? = nil
    public var footnoteColor: Color? = nil
    public var cardHeight: CGFloat = 132

    public init(
        title: String,
        value: String,
        valueColor: Color? = nil,
        subtitle: String = "",
        customSubtitle: Text? = nil,
        icon: String,
        tint: Color,
        footnote: String? = nil,
        footnoteColor: Color? = nil,
        cardHeight: CGFloat = 132
    ) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.subtitle = subtitle
        self.customSubtitle = customSubtitle
        self.icon = icon
        self.tint = tint
        self.footnote = footnote
        self.footnoteColor = footnoteColor
        self.cardHeight = cardHeight
    }

    public var body: some View {
        LiquidGlassCard(cornerRadius: 18, padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // 1. Cabeçalho com altura estritamente padronizada
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)

                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)
                }
                .frame(height: 32, alignment: .top)

                // 2. Valor Principal em Destaque
                Text(value)
                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor ?? .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()

                // 3. Subtítulo (com altura fixa para manter alinhamento rigoroso)
                Group {
                    if let customSubtitle {
                        customSubtitle
                    } else {
                        Text(subtitle)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 9.5))
                .lineLimit(2)
                .frame(height: 26, alignment: .topLeading)

                Spacer(minLength: 0)

                // 4. Rodapé
                if let footnote {
                    Text(footnote)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(footnoteColor ?? .secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: cardHeight, alignment: .topLeading)
        }
    }
}
