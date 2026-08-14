#include "window_ext_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <windowsx.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_COLOR_NONE
#define DWMWA_COLOR_NONE 0xFFFFFFFE
#endif

#ifndef DWMWCP_DONOTROUND
#define DWMWCP_DONOTROUND 1
#endif

#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

namespace window_ext {


std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>,
    std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
    channel = nullptr;


// static
void WindowExtPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "window_ext",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WindowExtPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WindowExtPlugin::WindowExtPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar(registrar) {
  WM_TASKBARCREATED = RegisterWindowMessage(TEXT("TaskbarCreated"));
  window_proc_id = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
}

WindowExtPlugin::~WindowExtPlugin() {
  registrar->UnregisterTopLevelWindowProcDelegate(window_proc_id);
}

std::optional<LRESULT> WindowExtPlugin::HandleWindowProc(HWND hWnd,
                                                           UINT message,
                                                           WPARAM wParam,
                                                           LPARAM lParam) {
  std::optional<LRESULT> result;
  if(message == WM_TASKBARCREATED){
    channel -> InvokeMethod("taskbarCreated", std::make_unique<flutter::EncodableValue>());
  }
  if (message == WM_NCCALCSIZE && frameless_) {
    // Treat the complete HWND as client content. Returning zero here is what
    // actually removes the left, right, and bottom resize frame painted by
    // Windows; making that frame transparent still leaves a visible seam on
    // some Windows 10/11 configurations.
    return 0;
  }
  if (message == WM_NCHITTEST && frameless_) {
    result = HitTestResizeBorder(hWnd, lParam);
    if (result.has_value()) {
      return result;
    }
  }
  return result;
}

std::optional<LRESULT> WindowExtPlugin::HitTestResizeBorder(HWND hwnd,
                                                            LPARAM lparam) {
  if (IsZoomed(hwnd) || IsIconic(hwnd)) {
    return std::nullopt;
  }

  RECT rect{};
  if (!GetWindowRect(hwnd, &rect)) {
    return std::nullopt;
  }

  const UINT window_dpi = GetDpiForWindow(hwnd);
  const int resize_border =
      MulDiv(8, window_dpi == 0 ? 96 : window_dpi, 96);
  const POINT cursor = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  const bool left = cursor.x >= rect.left &&
                    cursor.x < rect.left + resize_border;
  const bool right = cursor.x < rect.right &&
                     cursor.x >= rect.right - resize_border;
  const bool top = cursor.y >= rect.top &&
                   cursor.y < rect.top + resize_border;
  const bool bottom = cursor.y < rect.bottom &&
                      cursor.y >= rect.bottom - resize_border;

  if (top && left) {
    return HTTOPLEFT;
  }
  if (top && right) {
    return HTTOPRIGHT;
  }
  if (bottom && left) {
    return HTBOTTOMLEFT;
  }
  if (bottom && right) {
    return HTBOTTOMRIGHT;
  }
  if (left) {
    return HTLEFT;
  }
  if (right) {
    return HTRIGHT;
  }
  if (top) {
    return HTTOP;
  }
  if (bottom) {
    return HTBOTTOM;
  }
  return std::nullopt;
}

void WindowExtPlugin::EnableFramelessWindow(HWND hwnd) {
  LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  style &= ~WS_CAPTION;
  style |= WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
  SetWindowLongPtr(hwnd, GWL_STYLE, style);
  frameless_ = true;

  // Remove the DWM outline before the first Flutter frame is presented.
  const COLORREF no_border = DWMWA_COLOR_NONE;
  DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &no_border,
                        sizeof(no_border));

  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);
}

void WindowExtPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("setFramelessWindow") == 0) {
    HWND hWnd = ::GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
    if (hWnd) {
      EnableFramelessWindow(hWnd);
    }
    result->Success();
  } else if (method_call.method_name().compare("setWindowCornerPreference") == 0) {
    HWND hWnd = ::GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
    if (hWnd) {
      const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (args) {
        auto round_it = args->find(flutter::EncodableValue("round"));
        if (round_it != args->end()) {
          bool round = std::get<bool>(round_it->second);
          DWORD preference = round ? DWMWCP_ROUND : DWMWCP_DONOTROUND;
          const HRESULT status = DwmSetWindowAttribute(
              hWnd, DWMWA_WINDOW_CORNER_PREFERENCE, &preference,
              sizeof(preference));
          static_cast<void>(status);
          // Window content is clipped by Flutter on Windows 10 and 11. The
          // HWND stays rectangular so native regions and DWM never disagree.
          SetWindowRgn(hWnd, nullptr, TRUE);
        }
      }
    }
    result->Success();
  } else if (method_call.method_name().compare("setWindowBrightness") == 0) {
    HWND hWnd = ::GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
    const auto *args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (hWnd && args) {
      auto dark_it = args->find(flutter::EncodableValue("dark"));
      if (dark_it != args->end()) {
        const BOOL dark = std::get<bool>(dark_it->second) ? TRUE : FALSE;
        DwmSetWindowAttribute(hWnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                              sizeof(dark));
        const COLORREF no_border = DWMWA_COLOR_NONE;
        const HRESULT border_status = DwmSetWindowAttribute(
            hWnd, DWMWA_BORDER_COLOR, &no_border, sizeof(no_border));
        if (FAILED(border_status)) {
          const COLORREF fallback_border =
              dark ? RGB(12, 17, 27) : RGB(242, 245, 250);
          DwmSetWindowAttribute(hWnd, DWMWA_BORDER_COLOR, &fallback_border,
                                sizeof(fallback_border));
        }
        RedrawWindow(hWnd, nullptr, nullptr,
                     RDW_FRAME | RDW_INVALIDATE | RDW_UPDATENOW);
      }
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace window_ext
