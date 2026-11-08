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
