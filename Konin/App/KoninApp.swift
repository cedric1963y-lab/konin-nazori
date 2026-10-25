import SwiftUI
import UIKit

final class KoninAppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}

enum OrientationControl {
    @MainActor static func use(_ mask: UIInterfaceOrientationMask) {
        KoninAppDelegate.orientationMask = mask
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        for w in scene.windows {
            w.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
}

/// Launch options used only for producing store screenshots in the simulator.
struct LaunchDemo {
    static let args = ProcessInfo.processInfo.arguments
    static var isOn: Bool { args.contains("-demo") }
    static func has(_ key: String) -> Bool { args.contains(key) }
    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

@main
struct KoninNazoriApp: App {
    @UIApplicationDelegateAdaptor(KoninAppDelegate.self) var appDelegate
    @StateObject private var book = EntryBook()
    @StateObject private var unlock = UnlockStore()
    @StateObject private var ruler = RealSizeRuler()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(book)
                .environmentObject(unlock)
                .environmentObject(ruler)
                .tint(Palette.ink)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var book: EntryBook
    @AppStorage("didFinishIntro") private var didFinishIntro = false
    @AppStorage("didCalibrate") private var didCalibrate = false

    var body: some View {
        Group {
            if !didFinishIntro {
                IntroPager { didFinishIntro = true }
            } else if !didCalibrate {
                NavigationStack {
                    RulerSetupView(isFirstRun: true) { didCalibrate = true }
                }
            } else {
                MainTabs()
            }
        }
        .onAppear {
            if LaunchDemo.isOn {
                didFinishIntro = LaunchDemo.value("-screen") != "intro"
                didCalibrate = LaunchDemo.value("-screen") != "ruler"
                book.fillSample()
            }
        }
    }
}
