// Sources/FinSense/Views/AIChat/AIChatMainView.swift
import SwiftUI

public struct AIChatMainView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var aiService: CloudAIService

    @State private var inputText: String = ""
    @State private var currentStreamingResponse: String = ""
    @State private var isModelSelectorPresented: Bool = false
    @FocusState private var isInputFocused: Bool

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        aiService: CloudAIService
    ) {
        self.store = store
        self.syncService = syncService
        self.aiService = aiService
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header com Modelo Selecionado
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FinSense AI")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)

                            Button {
                                isModelSelectorPresented = true
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(aiService.activeModelId != nil ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
                                        .frame(width: 7, height: 7)
                                    Text(activeModelDisplayName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.clearChatHistory()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                                .padding(8)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                    // Lista de Mensagens
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(store.chatHistory) { msg in
                                    ChatMessageBubble(message: msg)
                                        .id(msg.id)
                                }

                                if aiService.isInferringChat {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color(hex: "#0284C7"))
                                                Text("FinSense AI")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(Color(hex: "#0284C7"))
                                            }

                                            if currentStreamingResponse.isEmpty {
                                                HStack(spacing: 4) {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle())
                                                        .scaleEffect(0.7)
                                                    Text("Pensando...")
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(Color.secondary)
                                                }
                                            } else {
                                                Text(currentStreamingResponse)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(Color.primary)
                                            }
                                        }
                                        .padding(14)
                                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))

                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .id("STREAMING_BUBBLE")
                                }

                                Color.clear.frame(height: 10).id("BOTTOM_SCROLL_ANCHOR")
                            }
                            .padding(.vertical, 8)
                        }
                        .onChange(of: store.chatHistory.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo("BOTTOM_SCROLL_ANCHOR", anchor: .bottom)
                            }
                        }
                        .onChange(of: currentStreamingResponse) { _, _ in
                            proxy.scrollTo("BOTTOM_SCROLL_ANCHOR", anchor: .bottom)
                        }
                    }

                    // Pílulas de Sugestões de Prompts Rápidos
                    AISuggestionPillView { prompt in
                        inputText = prompt
                        sendMessage()
                    }

                    // Campo de Envio de Mensagem
                    HStack(spacing: 10) {
                        TextField("Pergunte sobre seus gastos, dívidas ou metas...", text: $inputText, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(1...4)
                            .focused($isInputFocused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.8))

                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.4) : Color(hex: "#0284C7")))
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiService.isInferringChat)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 68)
                }
            }
            .sheet(isPresented: $isModelSelectorPresented) {
                ModelSelectorSheet(aiService: aiService, baseURL: syncService.baseURLString)
            }
            .task {
                await aiService.fetchModelsCatalog(baseURL: syncService.baseURLString)
            }
        }
    }

    private var activeModelDisplayName: String {
        if let id = aiService.activeModelId,
           let model = aiService.availableModels.first(where: { $0.id == id }) {
            return model.displayName
        }
        return "Selecione o Modelo de IA"
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        inputText = ""
        isInputFocused = false

        store.addChatMessage(role: .user, content: text)
        currentStreamingResponse = ""

        Task {
            // Constrói prompt com contexto financeiro resumido
            var messages = store.chatHistory
            let systemContext = buildFinancialSystemPrompt()
            messages.insert(ChatMessage(role: .system, content: systemContext), at: 0)

            do {
                let fullAnswer = try await aiService.streamChatMessage(
                    messages: messages,
                    baseURL: syncService.baseURLString
                ) { token in
                    currentStreamingResponse += token
                }

                store.addChatMessage(
                    role: .assistant,
                    content: fullAnswer,
                    modelUsed: aiService.activeModelId
                )
                currentStreamingResponse = ""
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                store.addChatMessage(
                    role: .assistant,
                    content: "Não foi possível conectar ao servidor de IA em \(syncService.baseURLString). Verifique se o backend está em execução."
                )
                currentStreamingResponse = ""
            }
        }
    }

    private func buildFinancialSystemPrompt() -> String {
        let income = store.monthlyIncome(for: store.selectedMonth)
        let expense = store.monthlyExpense(for: store.selectedMonth)
        let balance = store.totalCurrentBalance
        let debts = store.totalDebtAmount

        return """
        Você é o FinSense AI, um assistente financeiro pessoal de altíssima precisão.
        Dados atuais do usuário:
        - Saldo Total em Contas: R$ \(String(format: "%.2f", balance))
        - Receitas do Mês: R$ \(String(format: "%.2f", income))
        - Despesas do Mês: R$ \(String(format: "%.2f", expense))
        - Passivo em Dívidas: R$ \(String(format: "%.2f", debts))
        - Quantidade de Contratos: \(store.contracts.count)
        Responda em Português do Brasil com clareza, empatia e cálculos exatos para ajudar o usuário a poupar e quitar dívidas.
        """
    }
}

public struct ChatMessageBubble: View {
    public let message: ChatMessage

    public var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "#0284C7"), Color(hex: "#0369A1")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: Color(hex: "#0284C7").opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#0284C7"))
                        Text("FinSense AI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#0284C7"))

                        if let model = message.modelUsed {
                            Text("• \(model)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)

                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 20)
    }
}
