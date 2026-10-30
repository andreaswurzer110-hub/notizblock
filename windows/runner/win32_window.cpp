#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include <algorithm>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

/// Hier merken sich alle Apps von Andreas ihre Fensterlage, je App ein Wert.
constexpr const wchar_t kPlacementRegKey[] = L"Software\\AW\\Fensterlage";

/// So wird die Lage gespeichert: Bildschirmkoordinaten in physischen Pixeln.
struct StoredPlacement {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
  LONG maximized;
};

/// Freier Bereich (ohne Taskleiste) des Bildschirms, auf dem |monitor| liegt.
RECT WorkArea(HMONITOR monitor) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  GetMonitorInfo(monitor, &info);
  return info.rcWork;
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& /*origin*/,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  placement_key_ = remember_placement_ ? title : std::wstring();

  // Wieder dort, wo das Fenster beim letzten Schließen war. Beim ersten Start
  // (oder wenn der Bildschirm von damals fehlt) mittig im freien Bereich des
  // Bildschirms mit dem Mauszeiger, nicht hinter einer Taskleiste und nie
  // größer als dieser Bereich. |origin| bleibt dafür unbenutzt.
  RECT frame;
  if (!LoadPlacement(&frame, &start_maximized_)) {
    POINT cursor{};
    GetCursorPos(&cursor);
    HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTOPRIMARY);
    UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    double scale_factor = dpi / 96.0;
    const RECT work = WorkArea(monitor);
    const LONG work_width = work.right - work.left;
    const LONG work_height = work.bottom - work.top;
    const LONG width =
        std::min<LONG>(Scale(size.width, scale_factor), work_width);
    const LONG height =
        std::min<LONG>(Scale(size.height, scale_factor), work_height);
    frame.left = work.left + (work_width - width) / 2;
    frame.top = work.top + (work_height - height) / 2;
    frame.right = frame.left + width;
    frame.bottom = frame.top + height;
  }

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW, frame.left, frame.top,
      frame.right - frame.left, frame.bottom - frame.top, nullptr, nullptr,
      GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_,
                    start_maximized_ ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
}

void Win32Window::SetRememberPlacement(bool remember) {
  remember_placement_ = remember;
}

bool Win32Window::LoadPlacement(RECT* rect, bool* maximized) const {
  if (placement_key_.empty()) {
    return false;
  }
  StoredPlacement stored{};
  DWORD stored_size = sizeof(stored);
  if (RegGetValue(HKEY_CURRENT_USER, kPlacementRegKey, placement_key_.c_str(),
                  RRF_RT_REG_BINARY, nullptr, &stored,
                  &stored_size) != ERROR_SUCCESS ||
      stored_size != sizeof(stored)) {
    return false;
  }
  RECT saved = {stored.left, stored.top, stored.right, stored.bottom};
  if (saved.right - saved.left < 100 || saved.bottom - saved.top < 100) {
    return false;
  }

  // Die Titelleiste muss auf einem angeschlossenen Bildschirm greifbar sein,
  // sonst (Bildschirm abgesteckt) lieber neu mittig öffnen.
  RECT title_bar = {saved.left, saved.top, saved.right, saved.top + 40};
  HMONITOR monitor = MonitorFromRect(&title_bar, MONITOR_DEFAULTTONULL);
  if (monitor == nullptr) {
    return false;
  }
  const RECT work = WorkArea(monitor);
  RECT visible;
  if (!IntersectRect(&visible, &title_bar, &work) ||
      visible.right - visible.left < 150) {
    return false;
  }

  // Ist der freie Bereich kleiner geworden (andere Auflösung, Taskleiste
  // verschoben), das Fenster hineinschieben und notfalls verkleinern.
  const LONG width = std::min(saved.right - saved.left, work.right - work.left);
  const LONG height = std::min(saved.bottom - saved.top, work.bottom - work.top);
  rect->left = std::max(work.left, std::min(saved.left, work.right - width));
  rect->top = std::max(work.top, std::min(saved.top, work.bottom - height));
  rect->right = rect->left + width;
  rect->bottom = rect->top + height;
  *maximized = stored.maximized != 0;
  return true;
}

void Win32Window::SavePlacement() const {
  if (placement_key_.empty() || window_handle_ == nullptr) {
    return;
  }
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window_handle_, &placement)) {
    return;
  }

  // rcNormalPosition zählt ab dem freien Bereich des Hauptbildschirms
  // (Taskleiste links oder oben verschiebt ihn); umrechnen in Bildschirm-
  // koordinaten, wie CreateWindow sie erwartet.
  HMONITOR primary = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  GetMonitorInfo(primary, &info);
  const LONG dx = info.rcWork.left - info.rcMonitor.left;
  const LONG dy = info.rcWork.top - info.rcMonitor.top;

  const RECT& normal = placement.rcNormalPosition;
  StoredPlacement stored = {
      normal.left + dx, normal.top + dy, normal.right + dx, normal.bottom + dy,
      placement.showCmd == SW_SHOWMAXIMIZED ||
              (placement.showCmd == SW_SHOWMINIMIZED &&
               (placement.flags & WPF_RESTORETOMAXIMIZED) != 0)
          ? 1
          : 0};
  RegSetKeyValue(HKEY_CURRENT_USER, kPlacementRegKey, placement_key_.c_str(),
                 REG_BINARY, &stored, sizeof(stored));
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    // Lage merken, bevor Plugins (z. B. window_manager) die Nachricht für sich
    // beanspruchen: beim Schließen, beim Verstecken in den Infobereich und
    // beim Abmelden/Herunterfahren, das keinen WM_DESTROY mehr schickt.
    if (message == WM_DESTROY ||
        (message == WM_SHOWWINDOW && wparam == FALSE) ||
        (message == WM_ENDSESSION && wparam == TRUE)) {
      that->SavePlacement();
    }
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
