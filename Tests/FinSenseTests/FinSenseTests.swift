// Tests/FinSenseTests/FinSenseTests.swift
import XCTest
@testable import FinSense

final class FinSenseTests: XCTestCase {
    var tempDirectoryURL: URL!
    var tempDatabaseURL: URL!

    override func setUp() {
        super.setUp()
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        tempDatabaseURL = tempDirectoryURL.appendingPathComponent("financial_database.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        super.tearDown()
    }

    @MainActor
    func testOfflineFirstPersistenceAndReload() throws {
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)

        // Cria conta bancária
        store.createAccount(name: "Nubank Teste", initialBalance: 1500.0)
        XCTAssertEqual(store.accounts.count, 1)

        let accountId = store.accounts.first!.id
        let categoryId = store.categories.first!.id

        // Cria transação
        let tx = store.createTransaction(
            name: "Compras Supermercado",
            amount: 250.0,
            date: Date(),
            type: .expense,
            isPaid: true,
            categoryId: categoryId,
            accountId: accountId
        )

        XCTAssertEqual(store.transactions.count, 1)
        XCTAssertEqual(store.accountBalance(for: accountId), 1250.0)

        // Recarrega banco a partir do disco
        let reloadedStore = FinancialDataStore(customFileURL: tempDatabaseURL)
        XCTAssertEqual(reloadedStore.accounts.count, 1)
        XCTAssertEqual(reloadedStore.accounts.first?.name, "Nubank Teste")
        XCTAssertEqual(reloadedStore.transactions.count, 1)
        XCTAssertEqual(reloadedStore.transactions.first?.id, tx.id)
        XCTAssertEqual(reloadedStore.accountBalance(for: accountId), 1250.0)
    }

    @MainActor
    func testExactDuplicatesPreservedWithDistinctUUIDs() throws {
        // Regra 06: Duas transações idênticas no mesmo dia, valor e descrição devem ter UUIDs distintos e NUNCA ser descartadas.
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)
        store.createAccount(name: "Itaú Teste", initialBalance: 500.0)
        let accountId = store.accounts.first!.id
        let categoryId = store.categories.first!.id
        let now = Date()

        let tx1 = store.createTransaction(
            name: "Café da Manhã",
            amount: 15.50,
            date: now,
            type: .expense,
            isPaid: true,
            categoryId: categoryId,
            accountId: accountId
        )

        let tx2 = store.createTransaction(
            name: "Café da Manhã",
            amount: 15.50,
            date: now,
            type: .expense,
            isPaid: true,
            categoryId: categoryId,
            accountId: accountId
        )

        XCTAssertNotEqual(tx1.id, tx2.id)
        XCTAssertEqual(store.transactions.count, 2)
        XCTAssertEqual(store.accountBalance(for: accountId), 500.0 - 31.0)
    }

    @MainActor
    func testAmortizationExtraordinarySAC() throws {
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)
        store.createAccount(name: "CAIXA", initialBalance: 50000.0)
        let accountId = store.accounts.first!.id
        let categoryId = store.categories.first!.id

        store.createContract(
            kind: .financing,
            name: "Financiamento Imóvel CAIXA",
            financingSubtype: .imovel,
            amortizationSystem: .sac,
            totalContractedAmount: 200000.0,
            installmentAmount: 2200.0,
            billingDay: 15,
            totalInstallments: 360,
            monthlyInterestRate: 0.85,
            accountId: accountId,
            categoryId: categoryId
        )

        let contract = store.contracts.first!
        XCTAssertEqual(contract.outstandingBalance, 200000.0)

        // Realiza amortização de 10.000
        store.recordAmortization(
            contractId: contract.id,
            amount: 10000.0,
            mode: .reduceTerm,
            paidFromAccountId: accountId
        )

        let updated = store.contracts.first!
        XCTAssertEqual(updated.outstandingBalance, 190000.0)
        XCTAssertEqual(updated.extraAmortizedTotal, 10000.0)
        XCTAssertEqual(updated.amortizationHistory.count, 1)

        // Verifica que o débito foi lançado na conta
        XCTAssertEqual(store.accountBalance(for: accountId), 40000.0)
    }

    @MainActor
    func testCategoryQuotaRedemptionGeneratesRealTransaction() throws {
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)
        store.createAccount(name: "Conta Corrente", initialBalance: 1000.0)
        let accountId = store.accounts.first!.id
        let categoryId = store.categories.first!.id

        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let month = cal.component(.month, from: Date())

        store.createQuota(
            categoryId: categoryId,
            name: "Galão de Água 20L",
            year: year,
            month: month,
            quantity: 4,
            unitPrice: 15.0
        )

        let quota = store.categoryQuotas.first!
        XCTAssertEqual(quota.plannedQuantity, 4)

        // Dá baixa em 2 galões
        store.redeemQuotaUnits(quotaId: quota.id, units: 2, accountId: accountId)

        // Verifica que transação foi criada e saldo da conta atualizado
        XCTAssertEqual(store.transactions.count, 1)
        let tx = store.transactions.first!
        XCTAssertEqual(tx.amount, 30.0)
        XCTAssertEqual(store.accountBalance(for: accountId), 970.0)

        // Verifica envelope da cota
        let envelopes = store.calculateQuotaEnvelopes(for: Date())
        XCTAssertEqual(envelopes.first?.consumedUnits, 2)
        XCTAssertEqual(envelopes.first?.pendingUnits, 2)
    }

    func testSyncPushPullSerialization() throws {
        let mutation = SyncMutationDTO(
            mutationId: UUID(),
            entityName: "bank_accounts",
            entityId: UUID(),
            operation: "UPSERT",
            updatedAt: "2026-11-08T01:00:00Z",
            payload: ["name": .string("Nubank")]
        )

        let request = SyncPushPullRequest(
            clientId: "test-client-id",
            clientLastSyncRevision: 42,
            mutations: [mutation]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SyncPushPullRequest.self, from: data)

        XCTAssertEqual(decoded.clientId, "test-client-id")
        XCTAssertEqual(decoded.sinceRevision, 42)
        XCTAssertEqual(decoded.clientLastSyncRevision, 42)
        XCTAssertEqual(decoded.mutations.count, 1)
        XCTAssertEqual(decoded.mutations.first?.entityName, "bank_accounts")
    }

    func testServerPayloadSafeDecoding() throws {
        let sampleServerJSON = """
        {
            "server_current_revision": 1717,
            "latest_revision": 1717,
            "applied_mutation_ids": [],
            "acknowledged_mutation_ids": [],
            "rejected_mutations": [],
            "server_changes": [
                {
                    "mutation_id": "11111111-1111-1111-1111-111111111111",
                    "entity_name": "financial_transactions",
                    "entity_id": "22222222-2222-2222-2222-222222222222",
                    "operation": "INSERT",
                    "updated_at": "2026-11-08T22:43:21.74302+00:00",
                    "data": {
                        "id": "22222222-2222-2222-2222-222222222222",
                        "user_id": "33333333-3333-3333-3333-333333333333",
                        "account_id": "44444444-4444-4444-4444-444444444444",
                        "category_id": "55555555-5555-5555-5555-555555555555",
                        "name": "Financiamento Imóvel",
                        "details": null,
                        "amount": 2658.04,
                        "date": "2026-11-08T22:43:21.74302+00:00",
                        "type": "expense",
                        "is_paid": false,
                        "statement_occurrence_index": 1,
                        "recurrence_mode": "installment",
                        "created_at": "2026-11-08T22:43:21.74302+00:00"
                    }
                }
            ],
            "deltas": {
                "bank_accounts": [
                    {
                        "id": "44444444-4444-4444-4444-444444444444",
                        "name": "Itaú",
                        "initial_balance": 1500.0,
                        "agency": null,
                        "account_number": null,
                        "created_at": "2026-11-08T22:43:21.724145+00:00"
                    }
                ],
                "financial_transactions": [
                    {
                        "id": "22222222-2222-2222-2222-222222222222",
                        "account_id": "44444444-4444-4444-4444-444444444444",
                        "category_id": "55555555-5555-5555-5555-555555555555",
                        "name": "Financiamento Imóvel",
                        "details": null,
                        "amount": 2658.04,
                        "date": "2026-11-08T22:43:21.74302+00:00",
                        "type": "expense",
                        "is_paid": false,
                        "created_at": "2026-11-08T22:43:21.74302+00:00"
                    }
                ]
            },
            "tombstones": []
        }
        """.data(using: .utf8)!

        let decoder = BackendAPIClient.makeFlexibleDateDecoder()
        let response = try decoder.decode(SyncPushPullResponse.self, from: sampleServerJSON)

        XCTAssertEqual(response.latestRevision, 1717)
        XCTAssertEqual(response.serverChanges?.count, 1)
        XCTAssertEqual(response.deltas?.bankAccounts?.count, 1)
        XCTAssertEqual(response.deltas?.financialTransactions?.count, 1)
        XCTAssertEqual(response.deltas?.bankAccounts?.first?.name, "Itaú")
        XCTAssertEqual(response.deltas?.financialTransactions?.first?.amount, 2658.04)
        XCTAssertEqual(response.deltas?.financialTransactions?.first?.isPaid, false)
    }

    func testAuthModelsSerialization() throws {
        let login = LoginRequestDTO(email: "test@finsense.com", password: "secretPassword123")
        let loginData = try JSONEncoder().encode(login)
        let loginDecoded = try JSONDecoder().decode(LoginRequestDTO.self, from: loginData)
        XCTAssertEqual(loginDecoded.email, "test@finsense.com")
        XCTAssertEqual(loginDecoded.password, "secretPassword123")

        let register = RegisterRequestDTO(email: "novo@finsense.com", password: "pass", fullName: "Usuário Teste")
        let regData = try JSONEncoder().encode(register)
        let regDecoded = try JSONDecoder().decode(RegisterRequestDTO.self, from: regData)
        XCTAssertEqual(regDecoded.fullName, "Usuário Teste")
        XCTAssertEqual(regDecoded.email, "novo@finsense.com")

        let authResponseJSON = """
        {
            "access_token": "mock_jwt_token_12345",
            "refresh_token": "mock_refresh_token_67890",
            "token_type": "bearer",
            "expires_in": 3600,
            "user": {
                "id": "11111111-2222-3333-4444-555555555555",
                "email": "teste@finsense.com",
                "full_name": "Maria Silva"
            }
        }
        """.data(using: .utf8)!

        let authResponse = try JSONDecoder().decode(AuthResponseDTO.self, from: authResponseJSON)
        XCTAssertEqual(authResponse.accessToken, "mock_jwt_token_12345")
        XCTAssertEqual(authResponse.refreshToken, "mock_refresh_token_67890")
        XCTAssertEqual(authResponse.user.fullName, "Maria Silva")
        XCTAssertEqual(authResponse.user.email, "teste@finsense.com")
    }

    @MainActor
    func testCloudSyncDisabledWhenUnauthenticated() throws {
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)
        let auth = AuthService()
        // Garante que está deslogado
        UserDefaults.standard.removeObject(forKey: "finsense_auth_access_token")
        UserDefaults.standard.removeObject(forKey: "finsense_auth_refresh_token")
        UserDefaults.standard.removeObject(forKey: "finsense_auth_user_summary")
        auth.restoreSession()

        XCTAssertFalse(auth.isAuthenticated)

        let sync = CloudSyncService(store: store, authService: auth)
        sync.isEnabled = true
        sync.evaluateInitialStatus()

        // Sem autenticação, o syncStatus deve ser disabled
        if case .disabled = sync.syncStatus {
            // Sucesso esperado
        } else {
            XCTFail("Status de sincronização deveria ser .disabled para usuário não autenticado")
        }
    }

    // MARK: - Unified Financial KPI Architecture & Card Refactoring Tests

    @MainActor
    func testUnifiedFinancialKPISummaryCalculations() throws {
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)
        store.createAccount(name: "Conta Corrente", initialBalance: 10000.0)
        let accountId = store.accounts.first!.id
        let categoryId = store.categories.first!.id

        let now = Date()

        // 1. Receitas: Habituais e Extraordinárias
        _ = store.createTransaction(
            name: "Salário Mensal",
            amount: 5000.0,
            date: now,
            type: .income,
            isPaid: true,
            categoryId: categoryId,
            accountId: accountId
        )
        _ = store.createTransaction(
            name: "Freelance Previsto",
            amount: 3000.0,
            date: now,
            type: .income,
            isPaid: false,
            categoryId: categoryId,
            accountId: accountId
        )
        _ = store.createTransaction(
            name: "13º Salário",
            amount: 2000.0,
            date: now,
            type: .income,
            isPaid: true,
            categoryId: categoryId,
            accountId: accountId
        )

        // 2. Despesas: Fixas e Variáveis
        _ = store.createTransaction(
            name: "Aluguel Mensal",
            amount: 2500.0,
            date: now,
            type: .expense,
            isPaid: true,
            categoryId: categoryId,
            accountId: accountId
        )
        _ = store.createTransaction(
            name: "Compras Mercado",
            amount: 1500.0,
            date: now,
            type: .expense,
            isPaid: false,
            categoryId: categoryId,
            accountId: accountId
        )

        // 3. Tetos e Cotas
        let cal = store.calendar
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        store.setProvision(categoryId: categoryId, year: year, month: month, amount: 800.0, repeatForFuture: true)
        store.createQuota(categoryId: categoryId, name: "Botijão de Gás", year: year, month: month, quantity: 2, unitPrice: 100.0, repeatForFuture: true)

        let summary = store.buildUnifiedFinancialKPISummary(referenceDate: now, isAnnual: false, referenceNow: now)

        // Validação de Receitas
        XCTAssertEqual(summary.receivedIncome, 7000.0)
        XCTAssertEqual(summary.pendingIncome, 3000.0)
        XCTAssertEqual(summary.projectedIncome, 10000.0)
        XCTAssertEqual(summary.habitualIncome, 8000.0)
        XCTAssertEqual(summary.extraordinaryIncome, 2000.0)

        // Validação de Despesas
        XCTAssertEqual(summary.paidExpense, 2500.0)
        XCTAssertEqual(summary.pendingExpense, 1500.0)
        XCTAssertEqual(summary.recordedExpense, 4000.0)
        XCTAssertEqual(summary.fixedExpenses, 2500.0)
        XCTAssertEqual(summary.variableExpenses, 1500.0)

        // Validação de Orçamentos e Cotas
        XCTAssertEqual(summary.categoryCeilingsRemaining, 800.0)
        XCTAssertEqual(summary.specificQuotasRemaining, 200.0)
        XCTAssertEqual(summary.remainingBudgetsAndQuotas, 1000.0)

        // Validação de Gastos Planejados e Sobra
        XCTAssertEqual(summary.totalPlannedExpenses, 5000.0)
        XCTAssertEqual(summary.surplusAfterPlanning, 5000.0)

        // Validação de Saldo Bancário
        XCTAssertEqual(summary.currentAccountBalanceNow, 10000.0 + 7000.0 - 2500.0)
        XCTAssertEqual(summary.projectedAccountBalance, 10000.0 + 10000.0 - 4000.0)
        XCTAssertEqual(summary.balanceIfAllBudgetsConsumed, summary.projectedAccountBalance - 1000.0)
    }

    @MainActor
    func testForwardDeletionScopeForCategoryProvision() throws {
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)
        let categoryId = store.categories.first!.id
        let cal = store.calendar
        let now = Date()
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)

        // Cria provisão recorrente no mês M
        store.setProvision(categoryId: categoryId, year: year, month: month, amount: 600.0, repeatForFuture: true)

        let envMonthM = store.provisionEnvelopes(for: now).first { $0.category.id == categoryId }
        XCTAssertNotNil(envMonthM)
        XCTAssertEqual(envMonthM?.estimatedAmount, 600.0)

        // Exclui a partir do mês seguinte M+1 em diante
        let nextMonth = cal.date(byAdding: .month, value: 1, to: now)!
        store.deleteCategoryProvision(categoryId: categoryId, for: nextMonth, scope: .fromThisMonthOnward)

        // No mês M, o teto deve ser preservado intacto
        let envStillM = store.provisionEnvelopes(for: now).first { $0.category.id == categoryId }
        XCTAssertNotNil(envStillM)
        XCTAssertEqual(envStillM?.estimatedAmount, 600.0)

        // No mês M+1 e M+2, o teto deve estar encerrado (0.0 ou ausente)
        let envMonthM1 = store.provisionEnvelopes(for: nextMonth).first { $0.category.id == categoryId }
        XCTAssertTrue(envMonthM1 == nil || envMonthM1?.estimatedAmount == 0.0)

        let monthM2 = cal.date(byAdding: .month, value: 2, to: now)!
        let envMonthM2 = store.provisionEnvelopes(for: monthM2).first { $0.category.id == categoryId }
        XCTAssertTrue(envMonthM2 == nil || envMonthM2?.estimatedAmount == 0.0)
    }

    @MainActor
    func testForwardDeletionScopeForCategoryQuota() throws {
        let store = FinancialDataStore(customFileURL: tempDatabaseURL)
        let categoryId = store.categories.first!.id
        let cal = store.calendar
        let now = Date()
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)

        store.createQuota(categoryId: categoryId, name: "Água Mineral", year: year, month: month, quantity: 4, unitPrice: 20.0, repeatForFuture: true)

        let initialQuota = store.calculateQuotaEnvelopes(for: now).first { $0.name == "Água Mineral" }
        XCTAssertNotNil(initialQuota)
        let seriesId = initialQuota!.seriesId

        // Exclui deste mês em diante a partir de M+1
        let nextMonth = cal.date(byAdding: .month, value: 1, to: now)!
        store.deleteCategoryQuota(seriesId: seriesId, for: nextMonth, scope: .fromThisMonthOnward)

        // No mês M, a cota deve ser mantida
        let envM = store.calculateQuotaEnvelopes(for: now).first { $0.seriesId == seriesId }
        XCTAssertNotNil(envM)
        XCTAssertEqual(envM?.plannedQuantity, 4)

        // No mês M+1, a cota deve estar encerrada (0 unidades)
        let envM1 = store.calculateQuotaEnvelopes(for: nextMonth).first { $0.seriesId == seriesId }
        XCTAssertTrue(envM1 == nil || envM1?.plannedQuantity == 0)
    }

    @MainActor
    func testPerennialAuthenticationRetention() throws {
        let auth = AuthService()
        // Define tokens e marca sessão ativa
        UserDefaults.standard.set("mock_token_abc", forKey: "finsense_auth_access_token")
        UserDefaults.standard.set("mock_refresh_123", forKey: "finsense_auth_refresh_token")
        UserDefaults.standard.set("mock_token_abc", forKey: "finsense_auth_access_token_backup")
        UserDefaults.standard.set("mock_refresh_123", forKey: "finsense_auth_refresh_token_backup")
        UserDefaults.standard.set(true, forKey: "finsense_auth_session_is_active")

        auth.restoreSession()
        XCTAssertTrue(auth.isAuthenticated)

        // Simula perda da chave primária (ex: falha transitória de keychain ou limpeza de cache)
        UserDefaults.standard.removeObject(forKey: "finsense_auth_access_token")
        auth.restoreSession()

        // Graças ao backup persistente e sessionActiveKey, a sessão permanece PERENE
        XCTAssertTrue(auth.isAuthenticated)

        // Limpeza final de teste
        Task {
            await auth.logout()
        }
    }
}
