import SwiftUI
import UIKit
import SafariServices

@main
struct MyResearchApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(ResearchStyle.accent)
                .onOpenURL { store.receive($0) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var keyboardVisible = false
    @State private var testSharing = false
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch store.selectedTab {
                case 1: LinksScreen()
                case 2: SettingsScreen()
                default: SearchScreen()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if !keyboardVisible || store.selectedTab != 0 {
                HStack(spacing: 0) {
                    tab("搜索", symbol: "magnifyingglass", index: 0)
                    tab("我的链接", symbol: "link", index: 1)
                    tab("设置", symbol: "slider.horizontal.3", index: 2)
                }
                .padding(.top, 7).padding(.bottom, 3)
                .background(ResearchStyle.surface)
                .overlay(alignment: .top) { Divider() }
            }
            if store.testMode && ProcessInfo.processInfo.arguments.contains("--share-fixture") {
                Button("分享测试文字") { testSharing = true }.accessibilityIdentifier("system-share-test")
            }
            if store.testMode, !store.lastOpenedURL.isEmpty {
                Text(store.lastOpenedURL).font(.caption2).lineLimit(1).accessibilityIdentifier("last-opened-url")
            }
        }
        .background(ResearchStyle.background)
        .sheet(isPresented: $testSharing) { SystemShareSheet(text: store.query, includeURL: true) }
        .fullScreenCover(isPresented: Binding(
            get: { store.safariURL != nil },
            set: { if !$0 { store.safariURL = nil } }
        )) {
            if let url = store.safariURL {
                InAppSafariView(url: url).ignoresSafeArea()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardVisible = frame.minY < UIScreen.main.bounds.height - 20
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
        .alert("提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("好", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
    private func tab(_ title: String, symbol: String, index: Int) -> some View {
        Button { store.selectedTab = index } label: {
            VStack(spacing: 4) { Image(systemName: symbol).font(.system(size: 20, weight: .medium)); Text(title).font(.caption2) }
                .frame(maxWidth: .infinity, minHeight: 45)
                .foregroundStyle(store.selectedTab == index ? ResearchStyle.accent : .secondary)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("tab-\(index)")
    }
}


struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        return SFSafariViewController(url: url, configuration: configuration)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
