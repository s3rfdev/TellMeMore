import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import CoreAudio
import CoreMedia
import AVFoundation

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(x: 0, y: 0, width: 1040, height: 760), display: true)
    self.center()
    self.minSize = NSSize(width: 320, height: 360)
    self.title = "TellMeMore"

    // Прозрачное окно: фон рисует Flutter (альфа задаётся в настройках приложения).
    self.isOpaque = false
    self.backgroundColor = .clear
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor

    // Без тени: плавающее окно без лишних рамок и теней
    self.hasShadow = false
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Запрос прав на микрофон при запуске (чтобы приложение появлялось в настройках macOS)
    AVCaptureDevice.requestAccess(for: .audio) { _ in }

    // Канал управления окном (перетаскивание, скрытие при шаринге, поверх всех окон, скриншот)
    let windowChannel = FlutterMethodChannel(
      name: "tellmemo/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "dragWindow":
        if let event = NSApp.currentEvent {
          self.performDrag(with: event)
          result(nil)
        } else {
          result(FlutterError(code: "NO_EVENT", message: "No event", details: nil))
        }
      case "setScreenShareHidden":
        let hidden = (call.arguments as? [String: Any])?["hidden"] as? Bool ?? false
        // NSWindow.SharingType: .none исключает окно из захвата экрана (Zoom, Meet, Teams, скриншоты)
        self.sharingType = hidden ? .none : .readOnly
        result(nil)
      case "setAlwaysOnTop":
        let onTop = (call.arguments as? [String: Any])?["alwaysOnTop"] as? Bool ?? false
        self.level = onTop ? .floating : .normal
        result(nil)
      case "setWindowOpacity":
        result(nil)
      case "captureScreen":
        if #available(macOS 10.15, *) {
          if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
              NSWorkspace.shared.open(url)
            }
            result(FlutterError(
              code: "PERMISSION_DENIED",
              message: "Требуется разрешение «Запись экрана». Системные настройки открыты — включите тумблер для TellMeMore и повторите попытку.",
              details: nil
            ))
            return
          }
        }
        let originalAlpha = self.alphaValue
        let originalSharing = self.sharingType
        self.sharingType = .none
        self.alphaValue = 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
          guard let self = self else {
            result(FlutterError(code: "DEALLOCATED", message: "Window deallocated", details: nil))
            return
          }
          defer {
            self.sharingType = originalSharing
            self.alphaValue = originalAlpha
          }
          let displayID = (self.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
          guard let image = CGDisplayCreateImage(displayID) else {
            result(FlutterError(code: "CAPTURE_FAILED", message: "Не удалось захватить экран. Проверьте разрешение «Запись экрана» в настройках macOS.", details: nil))
            return
          }

          // Оптимизация размера для быстродействия LLM:
          // Retina 3K/4K скриншоты (3000+ px) заставляют модель тратить 8+ секунд на обработку
          // десятков vision-тайлов и передачу мегабайт base64. Масштабируем до макс. 1536 px:
          // текст и код остаются идеально чёткими для OCR, а вес файла падает в 8-10 раз (~200 КБ),
          // сокращая время ответа Gemini / GPT / Claude до минимума.
          let origWidth = CGFloat(image.width)
          let origHeight = CGFloat(image.height)
          let maxDimension: CGFloat = 1536.0

          let scaledImage: CGImage
          if origWidth > maxDimension || origHeight > maxDimension {
            let scale = min(maxDimension / origWidth, maxDimension / origHeight)
            let targetWidth = max(1, Int(origWidth * scale))
            let targetHeight = max(1, Int(origHeight * scale))

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

            if let context = CGContext(
              data: nil,
              width: targetWidth,
              height: targetHeight,
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: colorSpace,
              bitmapInfo: bitmapInfo
            ) {
              context.interpolationQuality = .high
              context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
              scaledImage = context.makeImage() ?? image
            } else {
              scaledImage = image
            }
          } else {
            scaledImage = image
          }

          let rep = NSBitmapImageRep(cgImage: scaledImage)
          guard let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.70]) else {
            result(FlutterError(code: "ENCODE_FAILED", message: "Failed to compress JPEG", details: nil))
            return
          }
          result(FlutterStandardTypedData(bytes: jpegData))
        }
      case "openScreenCaptureSettings":
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Канал захвата системного звука (ScreenCaptureKit, macOS 13+).
    if #available(macOS 13.0, *) {
      let channel = FlutterEventChannel(
        name: "tellmemo/system_audio",
        binaryMessenger: flutterViewController.engine.binaryMessenger)
      channel.setStreamHandler(SystemAudioStreamHandler())
    }

    super.awakeFromNib()
  }
}

/// Захват системного звука через ScreenCaptureKit: аудио-поток выбранного
/// дисплея (весь системный звук) конвертируется в PCM s16le 16k mono и
/// отправляется в Dart чанками по 100 мс.
@available(macOS 13.0, *)
class SystemAudioStreamHandler: NSObject, FlutterStreamHandler, SCStreamOutput {
  private var sink: FlutterEventSink?
  private var stream: SCStream?
  private var pcmBuffer = Data()
  private let pcmLock = NSLock()

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    self.sink = eventSink
    Task { await start() }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    Task { await stop() }
    sink = nil
    return nil
  }

  private func start() async {
    // Разрешение «Запись экрана» (так macOS классифицирует захват системного звука).
    if !CGPreflightScreenCaptureAccess() {
      let granted = CGRequestScreenCaptureAccess()
      if !granted {
        sink?(FlutterError(code: "PERMISSION",
                           message: "Требуется разрешение «Запись экрана» (Системные настройки → Конфиденциальность)",
                           details: nil))
        return
      }
    }

    do {
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
      guard let display = content.displays.first else {
        sink?(FlutterError(code: "NO_DISPLAY", message: "Дисплей не найден", details: nil))
        return
      }
      // Аудио «дисплея» = весь системный звук; своё окно исключаем (нет эха).
      let filter = SCContentFilter(display: display, excludingWindows: [])
      let config = SCStreamConfiguration()
      config.capturesAudio = true
      config.excludesCurrentProcessAudio = true

      let scStream = SCStream(filter: filter, configuration: config, delegate: nil)
      try scStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: nil)
      try await scStream.startCapture()
      self.stream = scStream
      sink?([
        "event": "started",
      ])
    } catch {
      sink?(FlutterError(code: "SCKIT", message: "\(error.localizedDescription)", details: nil))
    }
  }

  private func stop() async {
    if let s = stream {
      try? await s.stopCapture()
      stream = nil
    }
  }

  /// CMSampleBuffer → s16le 16k mono (чанки 3200Б). Формат из ASBD.
  private var didPrintFormat = false

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
              of type: SCStreamOutputType) {
    guard type == .audio, sampleBuffer.isValid else { return }
    guard let fd = CMSampleBufferGetFormatDescription(sampleBuffer),
          let asbd = fd.audioStreamBasicDescription else { return }

    if !didPrintFormat {
      didPrintFormat = true
      print("[SCK-FMT] id=\(String(asbd.mFormatID, radix: 16)) flags=\(String(asbd.mFormatFlags, radix: 16)) bits=\(asbd.mBitsPerChannel) ch=\(asbd.mChannelsPerFrame) rate=\(asbd.mSampleRate) bps=\(asbd.mBytesPerPacket)")
    }

    let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
    let nonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
    let channels = max(1, Int(asbd.mChannelsPerFrame))
    let inRate = asbd.mSampleRate > 0 ? asbd.mSampleRate : 48000

    guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
    let length = CMBlockBufferGetDataLength(dataBuffer)
    guard length > 0 else { return }
    var dataPointer: UnsafeMutablePointer<Int8>?
    guard CMBlockBufferGetDataPointer(
            dataBuffer, atOffset: 0, lengthAtOffsetOut: nil,
            totalLengthOut: nil, dataPointerOut: &dataPointer) == noErr,
          let ptr = dataPointer else { return }

    let bytesPerSample = isFloat ? 4 : 2
    // Полное число сэмплов (по всем каналам) в буфере.
    let totalSamples = length / bytesPerSample
    guard totalSamples > 0 else { return }

    var samples16 = [Int16]()
    samples16.reserveCapacity(totalSamples)

    if isFloat {
      ptr.withMemoryRebound(to: Float32.self, capacity: totalSamples) { fp in
        if nonInterleaved {
          // Плоскости каналов подряд: берём первую (plane0) длиной total/ch.
          let plane = totalSamples / channels
          for i in 0..<plane {
            let v = fp[i]
            samples16.append(Int16(max(-32768, min(32767, Int32(v * 32767)))))
          }
        } else {
          for i in 0..<totalSamples {
            let v = fp[i]
            samples16.append(Int16(max(-32768, min(32767, Int32(v * 32767)))))
          }
        }
      }
    } else {
      ptr.withMemoryRebound(to: Int16.self, capacity: totalSamples) { ip in
        if nonInterleaved {
          let plane = totalSamples / channels
          for i in 0..<plane { samples16.append(ip[i]) }
        } else {
          for i in 0..<totalSamples { samples16.append(ip[i]) }
        }
      }
    }

    // interleaved стерео → моно (усреднение)
    if channels > 1 && !nonInterleaved {
      var mono = [Int16]()
      mono.reserveCapacity(samples16.count / channels)
      var i = 0
      while i + channels <= samples16.count {
        var sum = 0
        for c in 0..<channels { sum += Int(samples16[i + c]) }
        mono.append(Int16(sum / channels))
        i += channels
      }
      samples16 = mono
    }

    // даунсемпл до 16к
    if inRate > 16000.5 {
      let step = Int((inRate / 16000).rounded())
      if step > 1 {
        var dec = [Int16]()
        dec.reserveCapacity(samples16.count / step)
        var i = 0
        while i < samples16.count {
          dec.append(samples16[i])
          i += step
        }
        samples16 = dec
      }
    }

    var pcm = Data(capacity: samples16.count * 2)
    for v in samples16 {
      pcm.append(UInt8(truncatingIfNeeded: v & 0xFF))
      pcm.append(UInt8(truncatingIfNeeded: (v >> 8) & 0xFF))
    }

    pcmLock.lock()
    pcmBuffer.append(pcm)
    while pcmBuffer.count >= 3200 {
      let payload = pcmBuffer.prefix(3200)
      pcmBuffer.removeFirst(3200)
      DispatchQueue.main.async { [weak self] in
        self?.sink?(payload)
      }
    }
    pcmLock.unlock()
  }
}
