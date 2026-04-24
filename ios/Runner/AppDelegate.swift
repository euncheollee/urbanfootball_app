import UIKit
import Flutter
import Photos

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  private let channelName = "urbanfootball/gallery"

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

    // 🔥 여기 추가 (핵심)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      if call.method == "saveImageToGallery" {

        guard let args = call.arguments as? [String: Any],
              let base64 = args["base64"] as? String else {
          result("invalid_data")
          return
        }

        self.saveImageToGallery(base64: base64, result: result)

      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return true
  }


  // 🔥 딥링크 받기 (여기에 추가)
  func application(...didFinishLaunching...) -> Bool {

    ...

    GeneratedPluginRegistrant.register(with: flutterViewController)

    ...

    // 🔥 여기 추가 (중요)
    if let url = launchOptions?[.url] as? URL {
      let link = url.absoluteString

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if let vc = self.window?.rootViewController as? FlutterViewController {
          let channel = FlutterMethodChannel(
            name: "deeplink_channel",
            binaryMessenger: vc.binaryMessenger
          )

          channel.invokeMethod("onDeepLink", arguments: link)
        }
      }
    }

    return true
  }

  // 🔥 갤러리 저장 함수
  private func saveImageToGallery(base64: String, result: @escaping FlutterResult) {

    guard let imageData = Data(base64Encoded: base64),
          let image = UIImage(data: imageData) else {
      result("invalid_data")
      return
    }

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      if status == .authorized || status == .limited {

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        DispatchQueue.main.async {
          result("ok")
        }

      } else {
        DispatchQueue.main.async {
          result("permission_denied")
        }
      }
    }
  }
}