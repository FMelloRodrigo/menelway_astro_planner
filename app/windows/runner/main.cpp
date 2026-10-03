#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Enforce single instance across the current user session
  const wchar_t kSingleInstanceMutexName[] =
      L"Local\\MenelwayAstroPlanner_SingleInstance_Mutex";
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  if (hMutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running. Find and bring its window to the foreground.
    HWND hwnd = nullptr;
    for (int retry = 0; retry < 25; ++retry) {
      hwnd = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Menelway Astro Planner");
      if (!hwnd) {
        hwnd = ::FindWindowW(nullptr, L"Menelway Astro Planner");
      }
      if (hwnd) {
        break;
      }
      ::Sleep(80);
    }

    if (hwnd != nullptr) {
      if (::IsIconic(hwnd)) {
        ::ShowWindow(hwnd, SW_RESTORE);
      } else {
        ::ShowWindow(hwnd, SW_SHOW);
      }
      ::SetForegroundWindow(hwnd);
      ::SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
      ::BringWindowToTop(hwnd);
    }

    ::CloseHandle(hMutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Menelway Astro Planner", origin, size)) {
    if (hMutex != nullptr) {
      ::ReleaseMutex(hMutex);
      ::CloseHandle(hMutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();

  if (hMutex != nullptr) {
    ::ReleaseMutex(hMutex);
    ::CloseHandle(hMutex);
  }

  return EXIT_SUCCESS;
}
