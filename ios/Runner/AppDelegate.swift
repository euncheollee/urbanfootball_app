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

  // 🔥 갤러리 채널
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

  // 🔥 앱 종료 상태 딥링크 처리
  if let url = launchOptions?[.url] as? URL {
    let link = url.absoluteString

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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

func application(
  _ app: UIApplication,
  open url: URL,
  options: [UIApplication.OpenURLOptionsKey : Any] = [:]
) -> Bool {

  let link = url.absoluteString

  if let vc = window?.rootViewController as? FlutterViewController {
    let channel = FlutterMethodChannel(
      name: "deeplink_channel",
      binaryMessenger: vc.binaryMessenger
    )

    channel.invokeMethod("onDeepLink", arguments: link)
  }

  return true
}

func application(
  _ application: UIApplication,
  continue userActivity: NSUserActivity,
  restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
) -> Bool {

  if let url = userActivity.webpageURL {
    let link = url.absoluteString

    if let vc = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "deeplink_channel",
        binaryMessenger: vc.binaryMessenger
      )

      channel.invokeMethod("onDeepLink", arguments: link)
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