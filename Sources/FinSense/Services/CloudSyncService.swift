// Sources/FinSense/Services/CloudSyncService.swift
import Foundation
import Combine
import Network
import SwiftUI
import UIKit

@MainActor
public final class CloudSyncService: ObservableObject {
    @Published public var syncStatus: SyncStatus = .disabled
    @Published public var isSyncing: Bool = false
    @Published public var pendingMutationsCount: Int = 0
    @Published public var lastSyncDate: Date? = nil

    @AppStorage("cloud_sync_enabled") public var isEnabled: Bool = false {
        didSet {
            evaluateInitialStatus()
            if isEnabled && (authService?.isAuthenticated ?? false) {
                scheduleSync(delaySeconds: 0.5)
            }
        }
    }
    @AppStorage("cloud_sync_base_url") public var baseURLString: String = AppConfiguration.shared.apiBaseURL
    @AppStorage("cloud_sync_client_id") public var clientId: String = UUID().uuidString
    @AppStorage("cloud_sync_last_revision") public var lastServerRevision: Int = 0
    @AppStorage("cloud_sync_last_user_id") public var lastSyncedUserId: String = ""

    public var canSync: Bool {
        isEnabled && (authService?.isAuthenticated ?? false)
    }

    private var outboxQueue: [LocalSyncMutation] = []
    private let outboxFileURL: URL
    private var debounceTimer: AnyCancellable? = nil
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable: Bool = true
    private var authCancellable: AnyCancellable? = nil
    public weak var store: FinancialDataStore?
    public weak var authService: AuthService? {
        didSet {
            authCancellable = authService?.$isAuthenticated
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isAuth in
                    guard let self else { return }
                    self.handleAuthChange(isAuth: isAuth)
                }
            if authService?.isAuthenticated ?? false {
                handleAuthChange(isAuth: true)
            } else {
                evaluateInitialStatus()
            }
        }
    }

    private func handleAuthChange(isAuth: Bool) {
        if isAuth {
            let currentUserId = authService?.currentUser?.id.uuidString ?? ""
            if !currentUserId.isEmpty && currentUserId != lastSyncedUserId {
                lastSyncedUserId = currentUserId
                lastServerRevision = 0
                outboxQueue.removeAll()
                saveOutboxQueue()
            }
            if !isEnabled {
                isEnabled = true
            }
            evaluateInitialStatus()
            scheduleSync(delaySeconds: 0.3)
        } else {
            lastSyncedUserId = ""
            evaluateInitialStatus()
        }
    }

    public func resetSyncState() {
        lastServerRevision = 0
        lastSyncDate = nil
        outboxQueue.removeAll()
        saveOutboxQueue()
        pendingMutationsCount = 0
        evaluateInitialStatus()
    }

    private func enqueueMutation(_ mutation: LocalSyncMutation) {
        if let existingIndex = outboxQueue.firstIndex(where: { $0.entityName == mutation.entityName && $0.entityId == mutation.entityId }) {
            outboxQueue[existingIndex] = mutation
        } else {
            outboxQueue.append(mutation)
        }
    }

    public init(store: FinancialDataStore? = nil, authService: AuthService? = nil) {
        self.store = store
        self.authService = authService
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.outboxFileURL = docs.appendingPathComponent("sync_outbox_queue.json")
        
        if let envBaseURL = ProcessInfo.processInfo.environment["API_BASE_URL"], !envBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.baseURLString = envBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        loadOutboxQueue()
        startNetworkMonitoring()
        evaluateInitialStatus()
    }

    public func evaluateInitialStatus() {
        if !isEnabled || !(authService?.isAuthenticated ?? false) {
            syncStatus = .disabled
        } else if !outboxQueue.isEmpty {
            syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Alterações pendentes")
        } else if let last = lastSyncDate {
            syncStatus = .synced(lastSync: last)
        } else {
            syncStatus = .synced(lastSync: Date())
        }
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isNetworkAvailable = (path.status == .satisfied)
                let isAuth = self.authService?.isAuthenticated ?? false
                if self.isNetworkAvailable && self.isEnabled && isAuth {
                    self.scheduleSync(delaySeconds: 1.0)
                } else if !self.isNetworkAvailable && self.isEnabled && isAuth {
                    self.syncStatus = .outOfSync(
                        pendingCount: self.outboxQueue.count,
                        reason: "Sem conexão com a internet"
                    )
                }
            }
        }
        let queue = DispatchQueue(label: "br.com.finsense.ios.syncNetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    public func recordLocalMutation<T: Codable>(
        entityName: String,
        entityId: UUID,
        operation: SyncOperation,
        entity: T? = nil
    ) {
        let isAuth = authService?.isAuthenticated ?? false
        guard isEnabled || isAuth else { return }
        if isAuth && !isEnabled {
            isEnabled = true
        }

        let payloadJSON: String? = {
            guard let entity, operation == .upsert else { return nil }
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(entity),
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }()

        let mutation = LocalSyncMutation(
            entityName: entityName,
            entityId: entityId,
            operation: operation,
            updatedAt: Date(),
            payloadJSON: payloadJSON
        )

        enqueueMutation(mutation)
        saveOutboxQueue()
        pendingMutationsCount = outboxQueue.count
        syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Alterações pendentes")
        if canSync {
            scheduleSync(delaySeconds: 1.5)
        }
    }

    public func scheduleSync(delaySeconds: Double) {
        let isAuth = authService?.isAuthenticated ?? false
        guard isEnabled, isNetworkAvailable, isAuth else { return }
        debounceTimer?.cancel()
        debounceTimer = Just(())
            .delay(for: .seconds(delaySeconds), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.performSync()
            }
    }

    public func performSync() {
        let isAuth = authService?.isAuthenticated ?? false
        guard isEnabled, isAuth else { syncStatus = .disabled; return }
        guard isNetworkAvailable else {
            syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Sem internet")
            return
        }
        guard !isSyncing else { return }

        isSyncing = true
        syncStatus = .syncing

        Task {
            await executeSyncPushPull()
        }
    }

    private func executeSyncPushPull() async {
        guard let store else { isSyncing = false; return }

        let effectiveSinceRevision: Int64
        if store.transactions.isEmpty && store.accounts.isEmpty && store.categories.isEmpty {
            effectiveSinceRevision = 0
        } else {
            effectiveSinceRevision = Int64(lastServerRevision)
        }

        let batchToSend = Array(outboxQueue.prefix(250))
        let payload = SyncPushPullRequest(
            clientId: clientId,
            sinceRevision: effectiveSinceRevision,
            clientLastSyncRevision: effectiveSinceRevision,
            mutations: batchToSend.map { mut in
                SyncMutationDTO(
                    mutationId: mut.id,
                    entityName: mut.entityName,
                    entityId: mut.entityId,
                    operation: mut.operation.rawValue,
                    updatedAt: ISO8601DateFormatter().string(from: mut.updatedAt),
                    payload: mut.payloadJSON.flatMap { try? JSONDecoder().decode([String: AnyCodableValue].self, from: Data($0.utf8)) }
                )
            }
        )

        do {
            let response = try await BackendAPIClient.shared.pushPull(
                baseURL: baseURLString,
                requestPayload: payload,
                token: authService?.accessToken
            )

            let ackIds = response.acknowledgedMutationIds
            let rejectedIds = response.rejectedMutations.map(\.mutationId)
            let processedSet = Set(ackIds + rejectedIds)
            outboxQueue.removeAll { processedSet.contains($0.id) }
            saveOutboxQueue()
            pendingMutationsCount = outboxQueue.count

            if !response.rejectedMutations.isEmpty {
                print("FinSense CloudSync: \(response.rejectedMutations.count) mutations rejected by server.")
            }

            if let deltas = response.deltas {
                applyDeltasToStore(deltas, tombstones: response.tombstones ?? [], into: store)
            }
            if let changes = response.serverChanges, !changes.isEmpty {
                applyServerChanges(changes, into: store)
            }

            lastServerRevision = Int(response.latestRevision)
            let now = Date()
            lastSyncDate = now

            if outboxQueue.isEmpty {
                syncStatus = .synced(lastSync: now)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Sincronizando lote seguinte...")
                scheduleSync(delaySeconds: 0.5)
            }
        } catch let err as URLError where err.code == .userAuthenticationRequired {
            syncStatus = .authError(message: "Sessão expirada. Faça login novamente.")
        } catch {
            // Degradação suave: servidor fora do ar ou timeout não trava o app
            syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Servidor indisponível")
        }

        isSyncing = false
    }

    private func applyServerChanges(_ changes: [SyncMutationDTO], into store: FinancialDataStore) {
        let decoder = BackendAPIClient.makeFlexibleDateDecoder()

        for change in changes {
            if change.operation == "DELETE" {
                switch change.entityName {
                case "financial_transactions": store.transactions.removeAll { $0.id == change.entityId }
                case "bank_accounts": store.accounts.removeAll { $0.id == change.entityId }
                case "categories": store.categories.removeAll { $0.id == change.entityId }
                case "investment_items": store.investments.removeAll { $0.id == change.entityId }
                case "debt_items": store.debts.removeAll { $0.id == change.entityId }
                case "credit_contracts": store.contracts.removeAll { $0.id == change.entityId }
                case "category_provisions": store.provisions.removeAll { $0.id == change.entityId }
                case "category_quota_rules": store.categoryQuotas.removeAll { $0.id == change.entityId }
                default: break
                }
            } else if let dataMap = change.data ?? change.payload,
                      let rawData = try? JSONEncoder().encode(dataMap) {
                switch change.entityName {
                case "financial_transactions":
                    if let item = try? decoder.decode(FinancialTransaction.self, from: rawData) {
                        if let idx = store.transactions.firstIndex(where: { $0.id == item.id }) { store.transactions[idx] = item }
                        else { store.transactions.append(item) }
                    }
                case "bank_accounts":
                    if let item = try? decoder.decode(BankAccount.self, from: rawData) {
                        if let idx = store.accounts.firstIndex(where: { $0.id == item.id }) { store.accounts[idx] = item }
                        else { store.accounts.append(item) }
                    }
                case "categories":
                    if let item = try? decoder.decode(CategoryItem.self, from: rawData) {
                        if let idx = store.categories.firstIndex(where: { $0.id == item.id }) { store.categories[idx] = item }
                        else { store.categories.append(item) }
                    }
                case "investment_items":
                    if let item = try? decoder.decode(InvestmentItem.self, from: rawData) {
                        if let idx = store.investments.firstIndex(where: { $0.id == item.id }) { store.investments[idx] = item }
                        else { store.investments.append(item) }
                    }
                case "debt_items":
                    if let item = try? decoder.decode(DebtItem.self, from: rawData) {
                        if let idx = store.debts.firstIndex(where: { $0.id == item.id }) { store.debts[idx] = item }
                        else { store.debts.append(item) }
                    }
                case "credit_contracts":
                    if let item = try? decoder.decode(CreditContract.self, from: rawData) {
                        if let idx = store.contracts.firstIndex(where: { $0.id == item.id }) { store.contracts[idx] = item }
                        else { store.contracts.append(item) }
                    }
                case "category_provisions":
                    if let item = try? decoder.decode(CategoryProvision.self, from: rawData) {
                        if let idx = store.provisions.firstIndex(where: { $0.id == item.id }) { store.provisions[idx] = item }
                        else { store.provisions.append(item) }
                    }
                case "category_quota_rules":
                    if let item = try? decoder.decode(CategoryQuotaRule.self, from: rawData) {
                        if let idx = store.categoryQuotas.firstIndex(where: { $0.id == item.id }) { store.categoryQuotas[idx] = item }
                        else { store.categoryQuotas.append(item) }
                    }
                default: break
                }
            }
        }
        store.saveToDisk()
        store.objectWillChange.send()
    }

    private func applyDeltasToStore(
        _ deltas: SyncDeltasContainerDTO,
        tombstones: [SyncTombstoneDTO],
        into store: FinancialDataStore
    ) {
        for tomb in tombstones {
            switch tomb.entityName {
            case "financial_transactions": store.transactions.removeAll { $0.id == tomb.entityId }
            case "bank_accounts": store.accounts.removeAll { $0.id == tomb.entityId }
            case "categories": store.categories.removeAll { $0.id == tomb.entityId }
            case "investment_items": store.investments.removeAll { $0.id == tomb.entityId }
            case "debt_items": store.debts.removeAll { $0.id == tomb.entityId }
            case "credit_contracts": store.contracts.removeAll { $0.id == tomb.entityId }
            case "category_provisions": store.provisions.removeAll { $0.id == tomb.entityId }
            case "category_quota_rules": store.categoryQuotas.removeAll { $0.id == tomb.entityId }
            default: break
            }
        }

        if let txs = deltas.financialTransactions {
            for item in txs {
                if let idx = store.transactions.firstIndex(where: { $0.id == item.id }) {
                    store.transactions[idx] = item
                } else {
                    store.transactions.append(item)
                }
            }
        }
        if let accs = deltas.bankAccounts {
            for item in accs {
                if let idx = store.accounts.firstIndex(where: { $0.id == item.id }) {
                    store.accounts[idx] = item
                } else {
                    store.accounts.append(item)
                }
            }
        }
        if let cats = deltas.categories {
            for item in cats {
                if let idx = store.categories.firstIndex(where: { $0.id == item.id }) {
                    store.categories[idx] = item
                } else {
                    store.categories.append(item)
                }
            }
        }
        if let invs = deltas.investmentItems {
            for item in invs {
                if let idx = store.investments.firstIndex(where: { $0.id == item.id }) {
                    store.investments[idx] = item
                } else {
                    store.investments.append(item)
                }
            }
        }
        if let debts = deltas.debtItems {
            for item in debts {
                if let idx = store.debts.firstIndex(where: { $0.id == item.id }) {
                    store.debts[idx] = item
                } else {
                    store.debts.append(item)
                }
            }
        }
        if let contracts = deltas.creditContracts {
            for item in contracts {
                if let idx = store.contracts.firstIndex(where: { $0.id == item.id }) {
                    store.contracts[idx] = item
                } else {
                    store.contracts.append(item)
                }
            }
        }
        if let provisions = deltas.categoryProvisions {
            for item in provisions {
                if let idx = store.provisions.firstIndex(where: { $0.id == item.id }) {
                    store.provisions[idx] = item
                } else {
                    store.provisions.append(item)
                }
            }
        }
        if let quotas = deltas.categoryQuotaRules {
            for item in quotas {
                if let idx = store.categoryQuotas.firstIndex(where: { $0.id == item.id }) {
                    store.categoryQuotas[idx] = item
                } else {
                    store.categoryQuotas.append(item)
                }
            }
        }

        store.saveToDisk()
        store.objectWillChange.send()
    }

    private func saveOutboxQueue() {
        guard let data = try? JSONEncoder().encode(outboxQueue) else { return }
        try? data.write(to: outboxFileURL, options: .atomic)
    }

    private func loadOutboxQueue() {
        guard let data = try? Data(contentsOf: outboxFileURL),
              let decoded = try? JSONDecoder().decode([LocalSyncMutation].self, from: data) else {
            self.outboxQueue = []
            return
        }
        self.outboxQueue = decoded
        self.pendingMutationsCount = decoded.count
    }

    public func queueEntireDatabaseForUpload(store: FinancialDataStore) {
        for acc in store.accounts {
            recordLocalMutation(entityName: "bank_accounts", entityId: acc.id, operation: .upsert, entity: acc)
        }
        for cat in store.categories {
            recordLocalMutation(entityName: "categories", entityId: cat.id, operation: .upsert, entity: cat)
        }
        for tx in store.transactions {
            recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .upsert, entity: tx)
        }
        for inv in store.investments {
            recordLocalMutation(entityName: "investment_items", entityId: inv.id, operation: .upsert, entity: inv)
        }
        for debt in store.debts {
            recordLocalMutation(entityName: "debt_items", entityId: debt.id, operation: .upsert, entity: debt)
        }
        for contract in store.contracts {
            recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        }
        for prov in store.provisions {
            recordLocalMutation(entityName: "category_provisions", entityId: prov.id, operation: .upsert, entity: prov)
        }
        for quota in store.categoryQuotas {
            recordLocalMutation(entityName: "category_quota_rules", entityId: quota.id, operation: .upsert, entity: quota)
        }
    }
}
