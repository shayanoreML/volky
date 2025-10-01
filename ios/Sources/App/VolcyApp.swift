//
//  VolcyApp.swift
//  Volcy
//
//  Main app entry point with dependency injection
//

import SwiftUI
import Combine

@main
struct VolcyApp: App {
    @StateObject private var container = DIContainer.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .preferredColorScheme(.light) // Breeze Clinical is light-first
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
    }

    private func setupAppearance() {
        // Configure global appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(VolcyColor.textPrimary)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(VolcyColor.textPrimary)
        ]
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active
            container.syncService.syncIfNeeded()
        case .inactive:
            // App about to become inactive
            break
        case .background:
            // App moved to background
            container.persistenceService.saveContext()
        @unknown default:
            break
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var container: DIContainer
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        Group {
            if container.userService.isOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(coordinator)
    }
}

// MARK: - App Coordinator

class AppCoordinator: ObservableObject {
    @Published var activeTab: AppTab = .home
    @Published var showingCapture: Bool = false
    @Published var showingSettings: Bool = false

    enum AppTab: String, CaseIterable {
        case home = "Home"
        case trends = "Trends"
        case regimen = "Regimen"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .trends: return "chart.line.uptrend.xyaxis"
            case .regimen: return "calendar"
            case .profile: return "person.fill"
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.activeTab) {
            ForEach(AppCoordinator.AppTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(VolcyColor.mint)
        .sheet(isPresented: $coordinator.showingCapture) {
            CaptureView()
        }
        .sheet(isPresented: $coordinator.showingSettings) {
            SettingsView()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppCoordinator.AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .trends:
            TrendsView()
        case .regimen:
            RegimenView()
        case .profile:
            ProfileView()
        }
    }
}

// MARK: - Placeholder Views

struct OnboardingView: View {
    var body: some View {
        Text("Onboarding - Coming Soon")
            .font(.largeTitle)
    }
}

struct HomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ZStack {
                VolcyColor.canvas.ignoresSafeArea()

                VStack {
                    Text("Volcy")
                        .font(.system(size: VolcyTypography.displaySize, weight: .bold))
                        .foregroundColor(VolcyColor.textPrimary)

                    Button(action: {
                        coordinator.showingCapture = true
                    }) {
                        Label("Start Scan", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(VolcyColor.mint)
                            .cornerRadius(VolcyRadius.button)
                    }
                    .padding(.horizontal, VolcySpacing.lg)
                }
            }
            .navigationTitle("Home")
        }
    }
}

struct TrendsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                VolcyColor.canvas.ignoresSafeArea()
                Text("Trends - Coming Soon")
                    .foregroundColor(VolcyColor.textSecondary)
            }
            .navigationTitle("Trends")
        }
    }
}

struct RegimenView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                VolcyColor.canvas.ignoresSafeArea()
                Text("Regimen - Coming Soon")
                    .foregroundColor(VolcyColor.textSecondary)
            }
            .navigationTitle("Regimen")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ZStack {
                VolcyColor.canvas.ignoresSafeArea()
                VStack {
                    Button("Settings") {
                        coordinator.showingSettings = true
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// CaptureView is now in Capture/CaptureView.swift

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                VolcyColor.canvas.ignoresSafeArea()
                Text("Settings - Coming Soon")
                    .foregroundColor(VolcyColor.textSecondary)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(VolcyColor.mint)
                }
            }
        }
    }
}
