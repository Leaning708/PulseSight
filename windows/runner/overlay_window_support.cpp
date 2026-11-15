#include "overlay_window_support.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace {
// Channels must outlive the handler invocation; one entry per overlay window.
// Intentionally leaked (runner process lifetime, one small object per window).
auto* g_channels =
    new std::vector<std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>>();
}  // namespace

void OverlayWindowSupport::Register(flutter::BinaryMessenger* messenger,
                                    HWND hwnd) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "pulsesight/overlay_window",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [hwnd](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        if (method == "setTransparent") {
          result->Success(true);
        } else if (method == "moveToBottomRight") {
          // The captured HWND may be the Flutter view (a child window);
          // position the actual top-level window.
          const HWND top_level = GetAncestor(hwnd, GA_ROOT);
          RECT work{};
          if (!SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0)) {
            result->Error("move_failed", "SPI_GETWORKAREA failed");
            return;
          }
          RECT window_rect{};
          GetWindowRect(top_level, &window_rect);
          const int width = window_rect.right - window_rect.left;
          const int height = window_rect.bottom - window_rect.top;
          // Margins match the macOS implementation (16 / 12).
          const int x = work.right - width - 16;
          const int y = work.bottom - height - 12;
          SetWindowPos(top_level, nullptr, x, y, 0, 0,
                       SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
          result->Success(true);
        } else {
          result->NotImplemented();
        }
      });
  g_channels->push_back(std::move(channel));
}
