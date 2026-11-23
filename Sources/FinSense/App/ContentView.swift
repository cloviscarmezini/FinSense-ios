// Sources/FinSense/App/ContentView.swift
import SwiftUI

public struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
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
            nativeLiquidTabView
                .tint(Color(hex: "#0284C7"))

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
            syncService.evaluateInitialStatus()
            syncService.setAppActive(scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, newPhase in
            syncService.setAppActive(newPhase == .active)
        }
    }

    @ViewBuilder
    private var nativeLiquidTabView: some View {
        let baseTabView = TabView(selection: $selectedTab) {
            DashboardView(
                store: store,
                syncService: syncService,
                authService: authService,
                selectedTab: $selectedTab
            )
            .background(NativeTabBarSwipeInstaller(selectedTab: $selectedTab).frame(width: 0, height: 0))
            .tabItem {
                Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.iconSymbol)
            }
            .tag(AppTab.dashboard)

            TransactionsListView(
                store: store,
                syncService: syncService,
                authService: authService
            )
            .tabItem {
                Label(AppTab.transactions.title, systemImage: AppTab.transactions.iconSymbol)
            }
            .tag(AppTab.transactions)

            FinanceHubMainView(
                store: store,
                syncService: syncService
            )
            .tabItem {
                Label(AppTab.financeHub.title, systemImage: AppTab.financeHub.iconSymbol)
            }
            .tag(AppTab.financeHub)

            SettingsMainView(
                store: store,
                syncService: syncService,
                authService: authService
            )
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.iconSymbol)
            }
            .tag(AppTab.settings)
        }

        if #available(iOS 26.0, *) {
            baseTabView
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            baseTabView
        }
    }
}
