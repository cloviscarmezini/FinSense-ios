// Sources/FinSense/Views/Navigation/SplashScreenView.swift
import SwiftUI

/// Splash screen de inicialização com o ícone oficial FinSense, aura ambiente e transição fluida.
public struct SplashScreenView: View {
    public var onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.85
    @State private var logoOpacity: Double = 0.0
    @State private var titleOpacity: Double = 0.0
    @State private var subtitleOpacity: Double = 0.0
    @State private var auraScale: CGFloat = 0.7
    @State private var auraOpacity: Double = 0.0

    public init(onFinished: @escaping () -> Void = {}) {
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            // Fundo escuro nativo do Liquid Design System
            LiquidColors.background(for: .dark)
                .ignoresSafeArea()

            // Brilho ambiente suave (Ciano & Roxo / Gradiente da marca)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#0284C7").opacity(0.35),
                                Color(hex: "#8B5CF6").opacity(0.20),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 180
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(auraScale)
                    .opacity(auraOpacity)
                    .blur(radius: 35)
            }

            VStack(spacing: 22) {
                Spacer()

                // Ícone oficial do App FinSense
                Image("app_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .shadow(color: Color(hex: "#0284C7").opacity(0.45), radius: 24, x: 0, y: 8)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("FinSense")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(hex: "#E2E8F0")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(titleOpacity)

                    Text("Inteligência & Controle Financeiro")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .tracking(1.2)
                        .opacity(subtitleOpacity)
                }

                Spacer()

                // Rodapé discreto
                Text("Versão 1.0")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .padding(.bottom, 24)
                    .opacity(subtitleOpacity)
            }
        }
        .onAppear {
            runAnimationSequence()
        }
    }

    private func runAnimationSequence() {
        // Entrada do Ícone e Aura
        withAnimation(.easeOut(duration: 0.55)) {
            logoScale = 1.0
            logoOpacity = 1.0
            auraScale = 1.0
            auraOpacity = 1.0
        }

        // Entrada do Título
        withAnimation(.easeOut(duration: 0.45).delay(0.2)) {
            titleOpacity = 1.0
        }

        // Entrada do Subtítulo e Rodapé
        withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
            subtitleOpacity = 1.0
        }

        // Conclusão e Transição suave para o Dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.35)) {
                onFinished()
            }
        }
    }
}
