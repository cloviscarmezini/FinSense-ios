// Sources/FinSense/DesignSystem/BRLCurrencyTextField.swift
import SwiftUI

/// Componente de entrada monetária formatada em tempo real no padrão Real Brasileiro (BRL / R$).
/// Trata a digitação da direita para a esquerda (centavos), suporte a backspace contínuo e colagem.
public struct BRLCurrencyTextField: View {
    public var placeholder: String
    @Binding public var text: String

    public init(_ placeholder: String = "R$ 0,00", text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .onChange(of: text) { _, newValue in
                let formatted = AppFormatters.formatCurrencyMaskedInput(newValue)
                if text != formatted {
                    text = formatted
                }
            }
            .onAppear {
                if !text.isEmpty {
                    let formatted = AppFormatters.formatCurrencyMaskedInput(text)
                    if text != formatted && !formatted.isEmpty {
                        text = formatted
                    }
                }
            }
    }
}

/// Modificador de View para aplicar a máscara monetária em qualquer TextField.
public struct BRLCurrencyMaskModifier: ViewModifier {
    @Binding public var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public func body(content: Content) -> some View {
        content
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .onChange(of: text) { _, newValue in
                let formatted = AppFormatters.formatCurrencyMaskedInput(newValue)
                if text != formatted {
                    text = formatted
                }
            }
            .onAppear {
                if !text.isEmpty {
                    let formatted = AppFormatters.formatCurrencyMaskedInput(text)
                    if text != formatted && !formatted.isEmpty {
                        text = formatted
                    }
                }
            }
    }
}

extension View {
    public func brlCurrencyMask(text: Binding<String>) -> some View {
        modifier(BRLCurrencyMaskModifier(text: text))
    }
}
