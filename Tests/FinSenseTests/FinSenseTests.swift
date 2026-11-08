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
        XCTAssertEqual(decoded.clientLastSyncRevision, 42)
        XCTAssertEqual(decoded.mutations.count, 1)
        XCTAssertEqual(decoded.mutations.first?.entityName, "bank_accounts")
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
}
