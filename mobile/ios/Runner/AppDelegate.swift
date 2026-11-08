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
    if #available(iOS 26.0, *),
       let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RespondaNativeNavigation") {
      registrar.register(
        RespondaTabBarFactory(messenger: registrar.messenger(), host: { [weak self] in self?.window?.rootViewController }),
        withId: "responda/native-tab-bar"
      )
    }
  }
}
