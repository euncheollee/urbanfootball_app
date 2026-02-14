import UIKit
import Flutter

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let flutterViewController = FlutterViewController(
      project: nil,
      nibName: nil,
      bundle: nil
    )

    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
    self.window = window

    GeneratedPluginRegistrant.register(with: flutterViewController)

    return true
  }
}
