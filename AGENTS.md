# Manifesto do Agente Antigravity — FinSense iOS

> **Documento Canônico de Arquitetura, Regras de Negócio e Diretrizes de Engenharia para Agentes Autônomos**  
> **Escopo:** Aplicativo Mobile iOS / iPadOS (`FinSense-ios`)  
> **Linguagem / Stack:** Swift 5.9+ / SwiftUI 5 (iOS 17.0+) / Liquid Glassmorphism / Xcode  
> **Repositório:** `FinSense-ios` (iOS App)

---

## ⚠️ Instruções Obrigatórias e Inegociáveis para Qualquer Agente

1. **Revisão e Manutenção Contínua deste Manifesto:**  
   Sempre que implementar novas telas, ajustar componentes de UI, alterar modelos de dados ou modificar regras de negócio, você **DEVE** revisar e atualizar este manifesto (`AGENTS.md`), mantendo-o sincronizado com o código.
2. **Commits Semânticos Obrigatórios:**  
   Toda alteração de código ou configuração deve ser acompanhada de commit semântico no padrão *Conventional Commits* (ex.: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `perf:`). **Nunca** faça commits genéricos e **nunca** suba alterações para repositórios remotos (`git push`) sem aprovação explícita.
3. **Validação de Compilação e Testes no Simulador iOS:**  
   Antes de finalizar tarefas, execute o build do projeto no simulador (`xcodebuild build -project FinSense.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`) e valide a suíte de testes com `xcodebuild test`.
4. **Fidelidade ao Design System Liquid Glass:**  
   O app adota o sistema visual *Modern Liquid Glass*: cards translúcidos com bordas suaves, efeitos de desfoque ultramodernos, paleta com contraste acessível, suporte total a gestos de swipe e sem conflito de toques em botões de ação rápida.

---

## 1. Visão Geral da Arquitetura do App iOS

```
FinSense-ios (Mobile App)
├── Sources/FinSense/
│   ├── DesignSystem/
│   │   ├── LiquidGlassModifiers.swift # LiquidGlassCard, LiquidKPICard, IntraMonthSparklineView
│   │   └── ThemeColors.swift          # Paleta de cores semântica (Emerald, Crimson, Amber, Slate)
│   ├── Models/
│   │   ├── FinancialTransaction.swift # Transações, Vale Intramês, DailyCashFlowPoint, Alertas
│   │   ├── CreditCardModels.swift     # Cartões, Faturas, Ciclos de Fechamento e Vencimento
│   │   ├── DomainModels.swift         # Contas, Categorias, Investimentos, Dívidas, Contratos
│   │   └── CloudSyncModels.swift      # Mutações locais, DTOs de Push-Pull e Status Check
│   ├── Services/
│   │   ├── FinancialDataStore.swift   # Store central (@MainActor ObservableObject) e persistência
│   │   ├── CloudSyncService.swift     # Sincronização delta two-way offline-first e status leve
│   │   ├── AuthService.swift          # Gestão de sessão JWT e renovação perene
│   │   └── KeychainHelper.swift       # Armazenamento seguro de credenciais e tokens
│   └── Views/
│       ├── Dashboard/
│       │   └── DashboardView.swift    # Resumo executivo, carrossel de faturas e grid de KPIs
│       ├── Transactions/
│       │   └── TransactionsListView.swift # Extrato com pílulas de filtro, linha de corte e swipe
│       ├── CreditCards/
│       │   └── CreditCardsListView.swift  # Lista de cartões, faturas abertas/fechadas e pagamento
│       ├── Contracts/
│       │   └── ContractsListView.swift    # Empréstimos e financiamentos (SAC e PRICE)
│       ├── Provisions/
│       │   └── ProvisionsView.swift   # Tetos orçamentários e cotas por categoria
│       └── Settings/
│           └── SettingsView.swift     # Status de sincronização, perfil e preferências
├── Tests/FinSenseTests/
│   └── FinSenseTests.swift            # Suíte automatizada de testes unitários do iOS
├── FinSense.xcodeproj                 # Projeto Xcode com schemes Debug e Release
└── Package.swift                      # Definição SwiftPM para gerenciamento de dependências
```

---

## 2. Catálogo de Regras de Negócio e Funcionalidades no iOS

### 2.1. Cartão de Crédito (Competência vs. Caixa)
- **Regime de Competência:** Compras no cartão impactam o orçamento e as categorias na data da compra.
- **Regime de Caixa:** Compras no cartão **não afetam** o saldo disponível da conta bancária no momento da compra. A saída real de dinheiro ocorre **exclusivamente quando a fatura é paga** (`isCreditCardInvoicePayment = true`).
- **Alocação Inteligente de Faturas:**
  - Compras efetuadas a partir do melhor dia de compra (`bestPurchaseDay`) caem automaticamente na fatura do mês seguinte.
  - Compras parceladas (1x a 24x) dividem o valor em centavos exatos entre as faturas seguintes; a primeira parcela absorve os centavos restantes.
  - O pagamento da fatura restaura imediatamente o limite do cartão (`usedLimit`) e não duplica as despesas por categoria nos relatórios.

### 2.2. Visibilidade do Descasamento de Caixa (Vale Intramês)
- **Ancoragem no Acumulado Consolidado Anterior:**
  - O cálculo do saldo diário cronológico parte de `accumulatedConsolidatedBalance(throughMonth: prevMonthEnd, includeProjectedUnpaid: !isClosed)`.
  - O cálculo em meses futuros respeita as provisões acumuladas anteriores sem duplicar as provisões do mês selecionado na linha do tempo das transações.
- **Dois Níveis de Alerta no Card de Saldo Previsto:**
  1. **`.confirmedDeficit` (Criticidade Alta, Vermelho `#EF4444`):**
     - Ocorre se há saldo acumulado negativo por transações em datas futuras ou não resolvidas até hoje (`!isResolvedByToday`), ou saldo final negativo.
     - Texto de alerta: `"Faltarão R$ X no dia dd/MM"` ou `"Faltarão R$ X no dia dd/MM e R$ Y no dia dd/MM"`.
  2. **`.possibleRisk` (Criticidade Menor, Laranja `#F59E0B`):**
     - Ocorre quando as transações agendadas fecham positivas, mas as previsões de gastos do mês podem levar o caixa ao negativo.
     - Texto de alerta: `"Possibilidade de caixa negativo (até R$ X c/ previsões)"`.
  3. **`.none`:**
     - Saldo positivo em todo o mês ou vale ocorrido no passado já normalizado por receita até hoje.
- **Indicadores Visuais no Extrato (`TransactionsListView`):**
  - Badge `LINHA DE CORTE` na transação que negativou o saldo acumulado.
  - Badge `CAIXA NEGATIVO` em saídas posteriores que aprofundam o déficit.
  - Badge `CAIXA NORMALIZADO` na entrada que recompõe o saldo positivo.
  - Mini gráfico sparkline destacando a zona negativa em vermelho.

### 2.3. Empréstimos e Financiamentos (SAC e PRICE)
- Modelagem de contratos com parcelas futuras geradas a partir da data de criação/referência (sem poluir o extrato com lançamentos do passado).
- Cálculo de amortização extraordinária reduzindo saldo devedor e prazo ou prestação.

### 2.4. Orçamentos, Tetos e Cotas
- Gestão de provisões por categoria e cotas de itens específicos.
- Escopos temporais de exclusão/alteração:
  - `.onlyThisMonth`: Modifica apenas o mês corrente.
  - `.fromThisMonthOnward`: Encerra a cota daquele mês em diante, preservando o passado.
  - `.allOccurrences`: Remove definitivamente todas as instâncias.

### 2.5. Sincronização Cloud Two-Way e Status Leve
- Persistência offline-first com fila local de mutações.
- Consulta ultra-rápida de status (`/api/v1/sync/status`) com ETag para atualizar o ícone de sincronização na barra superior sem travar a navegação.
- Atualização manual via toque no cabeçalho ou pull-to-refresh.

---

## 3. Instruções de Build e Execução de Testes no iOS

```bash
# Compilar para o Simulador iOS
xcodebuild build -project FinSense.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# Executar testes unitários automatizados no simulador via SwiftPM workspace
xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme FinSense -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FinSenseTests CODE_SIGNING_ALLOWED=NO
```
