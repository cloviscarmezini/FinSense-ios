// Sources/FinSense/Views/AIChat/AIChatMainView.swift
import SwiftUI

public struct AIChatMainView: View {
    @ObservedObject var store: FinancialDataStore
    @ObservedObject var syncService: CloudSyncService
    @ObservedObject var aiService: CloudAIService
    @ObservedObject var authService: AuthService

    @State private var inputText: String = ""
    @State private var currentStreamingResponse: String = ""
    @State private var isAuthSheetPresented: Bool = false
    @FocusState private var isInputFocused: Bool

    public init(
        store: FinancialDataStore,
        syncService: CloudSyncService,
        aiService: CloudAIService,
        authService: AuthService
    ) {
        self.store = store
        self.syncService = syncService
        self.aiService = aiService
        self.authService = authService
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidColors.background(for: .dark)
                    .ignoresSafeArea()

                if !authService.isAuthenticated {
                    // Tela de Bloqueio com Solicitação de Autenticação
                    unauthenticatedView
                } else {
                    // Chat com IA Autenticado
                    chatContentView
                }
            }
            .sheet(isPresented: $isAuthSheetPresented) {
                AuthSheetView(authService: authService, baseURL: syncService.baseURLString)
            }
        }
    }

    // MARK: - Estado Não Autenticado
    private var unauthenticatedView: some View {
        VStack(spacing: 24) {
            Spacer()

            LiquidGlassCard(cornerRadius: 26, padding: 24) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: "#0284C7"), Color(hex: "#38BDF8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 76, height: 76)
                            .shadow(color: Color(hex: "#0284C7").opacity(0.4), radius: 14, x: 0, y: 7)

                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("FinSense AI")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)

                        Text("Inteligência Financeira em Nuvem")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#0284C7"))
                    }

                    Text("Para utilizar a inteligência artificial, diagnósticos automatizados e projeções de quitação, é necessário conectar sua conta FinSense.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 10)

                    Divider().opacity(0.4)

                    VStack(alignment: .leading, spacing: 10) {
                        benefitRow(icon: "lock.shield.fill", title: "Processamento Seguro", subtitle: "Comunicação criptografada com autenticação JWT")
                        benefitRow(icon: "arrow.triangle.2.circlepath", title: "Sincronização Integrada", subtitle: "Seus dados locais sincronizam perfeitamente na nuvem")
                        benefitRow(icon: "brain.head.profile", title: "Diagnósticos Pessoais", subtitle: "Cálculos exatos de SAC/Price e sobra líquida")
                    }
                    .padding(.vertical, 4)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isAuthSheetPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Entrar ou Criar Conta")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#0284C7"), Color(hex: "#0369A1")], startPoint: .leading, endPoint: .trailing))
                        )
                        .shadow(color: Color(hex: "#0284C7").opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Color.clear.frame(height: 70)
        }
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "#0284C7"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    // MARK: - Conteúdo do Chat Autenticado
    private var chatContentView: some View {
        VStack(spacing: 0) {
            // Header sem seletor de modelo (usando default da API)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FinSense AI")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text("Assistente Financeiro Pessoal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        inputText = ""
        isInputFocused = false

        store.addChatMessage(role: .user, content: text)
        currentStreamingResponse = ""

        Task {
            var messages = store.chatHistory
            let systemContext = buildFinancialSystemPrompt()
            messages.insert(ChatMessage(role: .system, content: systemContext), at: 0)

            do {
                let fullAnswer = try await aiService.streamChatMessage(
                    messages: messages,
                    baseURL: syncService.baseURLString,
                    bearerToken: authService.accessToken
                ) { token in
                    currentStreamingResponse += token
                }

                store.addChatMessage(
                    role: .assistant,
                    content: fullAnswer
                )
                currentStreamingResponse = ""
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch let err as URLError where err.code == .userAuthenticationRequired {
                store.addChatMessage(
                    role: .assistant,
                    content: "Sua sessão expirou. Por favor, autentique-se novamente nas configurações."
                )
                currentStreamingResponse = ""
            } catch {
                store.addChatMessage(
                    role: .assistant,
                    content: "Não foi possível conectar ao assistente de IA em \(syncService.baseURLString). Verifique a conexão com o servidor."
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
