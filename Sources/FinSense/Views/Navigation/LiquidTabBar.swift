// Sources/FinSense/Views/Navigation/LiquidTabBar.swift
import SwiftUI
import UIKit

public enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case transactions = 1
    case financeHub = 2
    case settings = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Início"
        case .transactions: return "Extrato"
        case .financeHub: return "Finanças"
        case .settings: return "Ajustes"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .transactions: return "list.bullet.rectangle.portrait.fill"
        case .financeHub: return "building.columns.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct NativeTabBarSwipeInstaller: UIViewControllerRepresentable {
    @Binding public var selectedTab: AppTab

    public init(selectedTab: Binding<AppTab>) {
        self._selectedTab = selectedTab
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(selectedTab: $selectedTab)
    }

    public func makeUIViewController(context: Context) -> SwipeHostViewController {
        let vc = SwipeHostViewController()
        vc.coordinator = context.coordinator
        return vc
    }

    public func updateUIViewController(_ uiViewController: SwipeHostViewController, context: Context) {
        context.coordinator.selectedTab = $selectedTab
        uiViewController.installGestureIfNeeded()
    }

    public final class SwipeHostViewController: UIViewController {
        weak var coordinator: Coordinator?

        public override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installGestureIfNeeded()
        }

        public override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            installGestureIfNeeded()
        }

        func installGestureIfNeeded() {
            guard let tabBar = tabBarController?.tabBar,
                  let coordinator else { return }
            let alreadyInstalled = tabBar.gestureRecognizers?.contains(where: { $0 === coordinator.panRecognizer }) ?? false
            if !alreadyInstalled {
                tabBar.addGestureRecognizer(coordinator.panRecognizer)
            }
        }
    }

    public final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var selectedTab: Binding<AppTab>
        lazy var panRecognizer: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            return pan
        }()
        private var didTriggerForCurrentGesture = false

        init(selectedTab: Binding<AppTab>) {
            self.selectedTab = selectedTab
        }

        public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
            switch pan.state {
            case .began:
                didTriggerForCurrentGesture = false
            case .changed:
                guard !didTriggerForCurrentGesture else { return }
                let translation = pan.translation(in: pan.view)
                guard abs(translation.x) >= 28 else { return }
                didTriggerForCurrentGesture = true

                let allTabs = AppTab.allCases
                guard let currentIdx = allTabs.firstIndex(of: selectedTab.wrappedValue) else { return }
                // Swipe para a esquerda avança; swipe para a direita volta (igual Apple Music)
                let nextIdx = translation.x < 0
                    ? min(allTabs.count - 1, currentIdx + 1)
                    : max(0, currentIdx - 1)
                if nextIdx != currentIdx {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab.wrappedValue = allTabs[nextIdx]
                    }
                }
            case .ended, .cancelled, .failed:
                didTriggerForCurrentGesture = false
            default:
                break
            }
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
