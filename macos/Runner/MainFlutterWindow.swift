import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(x: 0, y: 0, width: 1040, height: 760), display: true)
    self.center()
    self.minSize = NSSize(width: 720, height: 520)
    self.title = "Tell Memo"

    // Прозрачное окно: фон рисует Flutter (альфа задаётся в настройках приложения).
    self.isOpaque = false
    self.backgroundColor = .clear
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
