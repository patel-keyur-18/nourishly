import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Share with Navmaas (ADR-012): the share file lives in the App Group
    // both apps belong to. The folder is derived data, so it stays out of
    // iCloud backup.
    let share = engineBridge.pluginRegistry.registrar(forPlugin: "NourishlyShare")!
    FlutterMethodChannel(name: "nourishly/share", binaryMessenger: share.messenger())
      .setMethodCallHandler { call, result in
        guard call.method == "groupDirectory" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let base = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: "group.com.patelkeyur.share")
        else {
          result(nil)
          return
        }
        var dir = base.appendingPathComponent("share", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        result(dir.path)
      }
  }
}
