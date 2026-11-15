#ifndef RUNNER_OVERLAY_WINDOW_SUPPORT_H_
#define RUNNER_OVERLAY_WINDOW_SUPPORT_H_

#include <windows.h>

#include <flutter/binary_messenger.h>

// Registers the "pulsesight/overlay_window" helper channel on a secondary
// window engine created by desktop_multi_window. This mirrors the macOS
// OverlayWindowSupport in MainFlutterWindow.swift:
// - setTransparent is a no-op success (transparency comes from window_manager's
//   frameless + clear background handling on Windows);
// - moveToBottomRight places the window at the bottom-right of the primary
//   monitor's work area, excluding the taskbar.
class OverlayWindowSupport {
 public:
  OverlayWindowSupport() = delete;

  // The channel object is kept alive for the process lifetime.
  static void Register(flutter::BinaryMessenger* messenger, HWND hwnd);

  OverlayWindowSupport(const OverlayWindowSupport&) = delete;
  OverlayWindowSupport& operator=(const OverlayWindowSupport&) = delete;
};

#endif  // RUNNER_OVERLAY_WINDOW_SUPPORT_H_
