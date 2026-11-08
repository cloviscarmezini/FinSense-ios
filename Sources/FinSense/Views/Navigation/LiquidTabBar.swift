// Sources/FinSense/Views/Navigation/LiquidTabBar.swift
import SwiftUI
import UIKit

public enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case transactions = 1
    case financeHub = 2
    case aiChat = 3
    case settings = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Início"
        case .transactions: return "Extrato"
        case .financeHub: return "Finanças"
        case .aiChat: return "FinSense AI"
        case .settings: return "Ajustes"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .transactions: return "list.bullet.rectangle.portrait.fill"
        case .financeHub: return "building.columns.fill"
        case .aiChat: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct LiquidTabBar: View {
    @Binding public var selectedTab: AppTab
    @Namespace private var animationNamespace

    public init(selectedTab: Binding<AppTab>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconSymbol)
                            .font(.system(size: 19, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? Color(hex: "#0284C7") : Color.secondary)
                            .scaleEffect(selectedTab == tab ? 1.12 : 1.0)

                        Text(tab.title)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color(hex: "#0284C7").opacity(0.12))
                                .matchedGeometryEffect(id: "ACTIVE_TAB_PILL", in: animationNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
