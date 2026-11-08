// Sources/FinSense/App/ContentView.swift
import SwiftUI

public struct ContentView: View {
    @StateObject private var store = FinancialDataStore()
    @StateObject private var authService: AuthService
    @StateObject private var syncService: CloudSyncService
    @StateObject private var aiService = CloudAIService()
    @State private var selectedTab: AppTab = .dashboard

    public init() {
        let s = FinancialDataStore()
        let auth = AuthService()
        let sync = CloudSyncService(store: s, authService: auth)
        s.cloudSyncService = sync
        _store = StateObject(wrappedValue: s)
        _authService = StateObject(wrappedValue: auth)
        _syncService = StateObject(wrappedValue: sync)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Conteúdo da Aba Ativa
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(
                        store: store,
                        syncService: syncService,
                        authService: authService,
                        selectedTab: $selectedTab
                    )
                case .transactions:
                    TransactionsListView(
                        store: store,
                        syncService: syncService,
                        aiService: aiService,
                        authService: authService
                    )
                case .financeHub:
                    FinanceHubMainView(
                        store: store,
                        syncService: syncService
                    )
                case .aiChat:
                    AIChatMainView(
                        store: store,
                        syncService: syncService,
                        aiService: aiService,
                        authService: authService
                    )
                case .settings:
                    SettingsMainView(
                        store: store,
                        syncService: syncService,
                        aiService: aiService,
                        authService: authService
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Barra Flutuante Liquid Glass
            LiquidTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            store.cloudSyncService = syncService
            syncService.store = store
            syncService.authService = authService
        }
    }
}
