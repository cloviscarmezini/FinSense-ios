// Sources/FinSense/App/ContentView.swift
import SwiftUI

public struct ContentView: View {
    @StateObject private var store = FinancialDataStore()
    @StateObject private var authService: AuthService
    @StateObject private var syncService: CloudSyncService
    @State private var selectedTab: AppTab = .dashboard
    @State private var isShowingSplash: Bool = true

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
        ZStack {
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
                            authService: authService
                        )
                    case .financeHub:
                        FinanceHubMainView(
                            store: store,
                            syncService: syncService
                        )
                    case .settings:
                        SettingsMainView(
                            store: store,
                            syncService: syncService,
                            authService: authService
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Barra Flutuante Liquid Glass
                LiquidTabBar(selectedTab: $selectedTab)
            }

            // Splash Screen com Ícone Oficial e Animação Fluida
            if isShowingSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isShowingSplash = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(999)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            store.cloudSyncService = syncService
            syncService.store = store
            syncService.authService = authService
            if authService.isAuthenticated {
                syncService.isEnabled = true
                syncService.scheduleSync(delaySeconds: 0.5)
            }
        }
    }
}
