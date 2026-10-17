#include "flutter_window.h"

#include <windows.h>
#include <algorithm>
namespace Gdiplus {
  using std::min;
  using std::max;
}
#include <gdiplus.h>

#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif
#ifndef WDA_NONE
#define WDA_NONE 0x00000000
#endif

namespace {

int GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
  UINT num = 0;          // number of image encoders
  UINT size = 0;         // size of the image encoder array in bytes
  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) return -1;
  std::vector<BYTE> buffer(size);
  Gdiplus::ImageCodecInfo* pImageCodecInfo =
      reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
  Gdiplus::GetImageEncoders(num, size, pImageCodecInfo);
  for (UINT j = 0; j < num; ++j) {
    if (wcscmp(pImageCodecInfo[j].MimeType, format) == 0) {
      *pClsid = pImageCodecInfo[j].Clsid;
      return static_cast<int>(j);
    }
  }
  return -1;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  // Initialize GDI+ for screen capture & image compression
  Gdiplus::GdiplusStartupInput gdiplusStartupInput;
  Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplusStartupInput, nullptr);

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  RegisterWindowChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;

  if (gdiplus_token_ != 0) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_token_ = 0;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterWindowChannel() {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "tellmemo/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        HWND hwnd = GetHandle();

        if (method == "dragWindow") {
          if (hwnd) {
            ::ReleaseCapture();
            ::SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
            result->Success();
          } else {
            result->Error("NO_WINDOW", "Window handle is null");
          }
        } else if (method == "setScreenShareHidden") {
          bool hidden = false;
          if (call.arguments()) {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
              auto it = args->find(flutter::EncodableValue("hidden"));
              if (it != args->end()) {
                if (const auto* b = std::get_if<bool>(&it->second)) {
                  hidden = *b;
                }
              }
            }
          }
          if (hwnd) {
            ::SetWindowDisplayAffinity(hwnd, hidden ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE);
          }
          result->Success();
        } else if (method == "setAlwaysOnTop") {
          bool onTop = false;
          if (call.arguments()) {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
              auto it = args->find(flutter::EncodableValue("alwaysOnTop"));
              if (it != args->end()) {
                if (const auto* b = std::get_if<bool>(&it->second)) {
                  onTop = *b;
                }
              }
            }
          }
          if (hwnd) {
            ::SetWindowPos(hwnd, onTop ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                           SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
          }
          result->Success();
        } else if (method == "closeWindow") {
          if (hwnd) {
            ::PostMessage(hwnd, WM_CLOSE, 0, 0);
          }
          result->Success();
        } else if (method == "minimizeWindow") {
          if (hwnd) {
            ::ShowWindow(hwnd, SW_MINIMIZE);
          }
          result->Success();
        } else if (method == "openScreenCaptureSettings") {
          result->Success();
        } else if (method == "captureScreen") {
          auto jpeg_bytes = CaptureScreenJpeg();
          if (jpeg_bytes.empty()) {
            result->Error("CAPTURE_FAILED", "Failed to capture screen or encode JPEG");
          } else {
            result->Success(flutter::EncodableValue(jpeg_bytes));
          }
        } else {
          result->NotImplemented();
        }
      });
}

std::vector<uint8_t> FlutterWindow::CaptureScreenJpeg() {
  HWND hwnd = GetHandle();

  // Temporarily make our window transparent during screenshot capture so
  // it is not included in the image, matching macOS behavior.
  LONG_PTR exStyle = 0;
  bool styleModified = false;
  if (hwnd) {
    exStyle = ::GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, exStyle | WS_EX_LAYERED);
    ::SetLayeredWindowAttributes(hwnd, 0, 0, LWA_ALPHA);
    ::UpdateWindow(hwnd);
    styleModified = true;
    ::Sleep(40);
  }

  int screenX = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  int screenY = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
  int screenWidth = ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
  int screenHeight = ::GetSystemMetrics(SM_CYVIRTUALSCREEN);

  if (screenWidth <= 0 || screenHeight <= 0) {
    screenX = 0;
    screenY = 0;
    screenWidth = ::GetSystemMetrics(SM_CXSCREEN);
    screenHeight = ::GetSystemMetrics(SM_CYSCREEN);
  }

  HDC hScreenDC = ::GetDC(nullptr);
  HDC hMemDC = ::CreateCompatibleDC(hScreenDC);
  HBITMAP hBitmap = ::CreateCompatibleBitmap(hScreenDC, screenWidth, screenHeight);
  HBITMAP hOldBitmap = static_cast<HBITMAP>(::SelectObject(hMemDC, hBitmap));

  ::BitBlt(hMemDC, 0, 0, screenWidth, screenHeight, hScreenDC, screenX, screenY,
           SRCCOPY | CAPTUREBLT);

  ::SelectObject(hMemDC, hOldBitmap);
  ::DeleteDC(hMemDC);
  ::ReleaseDC(nullptr, hScreenDC);

  // Restore window visibility
  if (hwnd && styleModified) {
    ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, exStyle);
    ::UpdateWindow(hwnd);
  }

  std::vector<uint8_t> result;

  {
    Gdiplus::Bitmap gdiBitmap(hBitmap, nullptr);
    int origW = gdiBitmap.GetWidth();
    int origH = gdiBitmap.GetHeight();
    if (origW <= 0 || origH <= 0) {
      ::DeleteObject(hBitmap);
      return result;
    }

    // Downscale so max dimension is 1536px, matching macOS implementation
    const float maxDimension = 1536.0f;
    int targetW = origW;
    int targetH = origH;
    if (origW > maxDimension || origH > maxDimension) {
      float scale = (std::min)(maxDimension / origW, maxDimension / origH);
      targetW = (std::max)(1, static_cast<int>(origW * scale));
      targetH = (std::max)(1, static_cast<int>(origH * scale));
    }

    std::unique_ptr<Gdiplus::Bitmap> targetBitmap;
    Gdiplus::Bitmap* finalBitmap = &gdiBitmap;

    if (targetW != origW || targetH != origH) {
      targetBitmap = std::make_unique<Gdiplus::Bitmap>(targetW, targetH, PixelFormat24bppRGB);
      Gdiplus::Graphics g(targetBitmap.get());
      g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
      g.DrawImage(&gdiBitmap, 0, 0, targetW, targetH);
      finalBitmap = targetBitmap.get();
    }

    CLSID clsidJpeg;
    if (GetEncoderClsid(L"image/jpeg", &clsidJpeg) != -1) {
      Gdiplus::EncoderParameters encoderParams;
      encoderParams.Count = 1;
      encoderParams.Parameter[0].Guid = Gdiplus::EncoderQuality;
      encoderParams.Parameter[0].Type = Gdiplus::EncoderParameterValueTypeLong;
      encoderParams.Parameter[0].NumberOfValues = 1;
      ULONG quality = 70;
      encoderParams.Parameter[0].Value = &quality;

      IStream* pStream = nullptr;
      if (::CreateStreamOnHGlobal(nullptr, TRUE, &pStream) == S_OK) {
        if (finalBitmap->Save(pStream, &clsidJpeg, &encoderParams) == Gdiplus::Ok) {
          STATSTG stat;
          if (pStream->Stat(&stat, STATFLAG_NONAME) == S_OK) {
            ULARGE_INTEGER streamSize = stat.cbSize;
            result.resize(streamSize.LowPart);
            LARGE_INTEGER liZero = {};
            pStream->Seek(liZero, STREAM_SEEK_SET, nullptr);
            ULONG bytesRead = 0;
            pStream->Read(result.data(), streamSize.LowPart, &bytesRead);
          }
        }
        pStream->Release();
      }
    }
  }

  ::DeleteObject(hBitmap);
  return result;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
