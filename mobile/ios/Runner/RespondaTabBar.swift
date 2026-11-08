import Flutter
import UIKit

@available(iOS 26.0, *)
final class RespondaTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let host: () -> UIViewController?

  init(messenger: FlutterBinaryMessenger, host: @escaping () -> UIViewController?) {
    self.messenger = messenger
    self.host = host
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    RespondaTabBarView(frame: frame, id: id, arguments: args, messenger: messenger, host: host())
  }
}

@available(iOS 26.0, *)
private final class RespondaTabController: UITabBarController, UITabBarControllerDelegate {
  var onPageSelected: ((Int) -> Void)?
  var onCall: (() -> Void)?
  private var applyingSelection = false
  private var tintValue: UInt32?

  init() {
    super.init(nibName: nil, bundle: nil)
    overrideUserInterfaceStyle = .light
    view.backgroundColor = .clear
    view.isOpaque = false
    view.clipsToBounds = false
    let symbols = ["house", "doc.text", "phone.fill", "info.circle", "gearshape"]
    tabs = symbols.enumerated().map { index, symbol in
      UITab(title: "", image: UIImage(systemName: symbol), identifier: String(index)) { _ in
        let page = UIViewController()
        page.view.backgroundColor = .clear
        return page
      }
    }
    tabBar.itemPositioning = .fill
    // Do not configure selection backgrounds: UIKit supplies its stock indicator.
    delegate = self
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func update(_ values: [String: Any]) {
    if let labels = values["labels"] as? [String], labels.count == 5 {
      for index in 0..<5 where tabs[index].title != labels[index] { tabs[index].title = labels[index] }
    }
    tabs[2].accessibilityLabel = values["callAccessibilityLabel"] as? String
    if let value = values["tint"] as? NSNumber, tintValue != value.uint32Value {
      let argb = value.uint32Value
      tintValue = argb
      let tint = UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                         green: CGFloat((argb >> 8) & 255) / 255,
                         blue: CGFloat(argb & 255) / 255, alpha: 1)
      tabBar.tintColor = tint
      tabs[2].image = Self.callImage(tint: tint)
    }
    if let page = values["pageIndex"] as? Int, (0..<4).contains(page) {
      let slot = page < 2 ? page : page + 1
      if selectedTab !== tabs[slot] {
        applyingSelection = true
        selectedTab = tabs[slot]
        applyingSelection = false
      }
    }
    view.isHidden = !(values["visible"] as? Bool ?? true)
  }

  func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
    if tab.identifier == "2" {
      onCall?()
      return false
    }
    return true
  }

  func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
    guard !applyingSelection, let slot = Int(selectedTab.identifier), slot != 2 else { return }
    onPageSelected?(slot < 2 ? slot : slot - 1)
  }

  private static func callImage(tint: UIColor) -> UIImage {
    let size: CGFloat = 44
    return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
      tint.setFill()
      UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
      let phone = UIImage(systemName: "phone.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26))?
        .withTintColor(.white, renderingMode: .alwaysOriginal)
      phone?.draw(in: CGRect(x: 9, y: 9, width: 26, height: 26))
    }.withRenderingMode(.alwaysOriginal)
  }
}

@available(iOS 26.0, *)
private final class RespondaTabBarView: NSObject, FlutterPlatformView {
  private let controller = RespondaTabController()
  private let container: UIView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger, host: UIViewController?) {
    container = UIView(frame: frame)
    channel = FlutterMethodChannel(name: "responda/native-tab-bar/\(id)", binaryMessenger: messenger)
    super.init()
    container.backgroundColor = .clear
    container.isOpaque = false
    container.clipsToBounds = false
    host?.addChild(controller)
    controller.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(controller.view)
    NSLayoutConstraint.activate([
      controller.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      controller.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      controller.view.topAnchor.constraint(equalTo: container.topAnchor),
      controller.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    if let host { controller.didMove(toParent: host) }
    controller.onPageSelected = { [weak self] index in self?.channel.invokeMethod("onPageSelected", arguments: index) }
    controller.onCall = { [weak self] in self?.channel.invokeMethod("onCall", arguments: nil) }
    controller.update(arguments as? [String: Any] ?? [:])
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      if call.method == "update", let values = call.arguments as? [String: Any] {
        self.controller.update(values)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  deinit {
    channel.setMethodCallHandler(nil)
    controller.willMove(toParent: nil)
    controller.view.removeFromSuperview()
    controller.removeFromParent()
  }
}
