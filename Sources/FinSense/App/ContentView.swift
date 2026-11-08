// Sources/FinSense/App/ContentView.swift
import SwiftUI

public struct ContentView: View {
    @StateObject private var store = FinancialDataStore()
    @StateObject private var syncService: CloudSyncService
    @StateObject private var aiService = CloudAIService()
    @State private var selectedTab: AppTab = .dashboard

    public init() {
        let s = FinancialDataStore()
        let sync = CloudSyncService(store: s)
        s.cloudSyncService = sync
        _store = StateObject(wrappedValue: s)
        _syncService = StateObject(wrappedValue: sync)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Conteúdo da Aba Ativa
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(store: store, syncService: syncService, selectedTab: $selectedTab)
                case .transactions:
                    TransactionsListView(store: store, syncService: syncService, aiService: aiService)
                case .financeHub:
                    FinanceHubMainView(store: store, syncService: syncService)
                case .aiChat:
                    AIChatMainView(store: store, syncService: syncService, aiService: aiService)
                case .settings:
                    SettingsMainView(store: store, syncService: syncService, aiService: aiService)
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
        }
    }
}
