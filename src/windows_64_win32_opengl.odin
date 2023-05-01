package main

import "core:fmt"
import "core:os"
import "core:runtime"
import "core:time"
import w32 "core:sys/windows"

import gl "vendor:OpenGL"

import "project:game"
import "project:graphics"
import gl_impl "project:graphics/opengl"
import "project:platform"
import win_impl "project:platform/windows"

foreign import user32 "system:User32.lib"
HACCEL :: distinct w32.HANDLE
@(default_calling_convention="stdcall")
foreign user32 {
  LoadAcceleratorsW :: proc(hInstance : w32.HINSTANCE, lpTableName : w32.LPCWSTR) -> HACCEL ---
  TranslateAcceleratorW :: proc(hWnd : w32.HWND, hAccTable : HACCEL, lpMsg : w32.LPMSG) -> u32 ---
}

////////////////////////////////////////////////////////////////////////////////////////////////////

  GAME_NAME :: "Long Tail"

  @(private="file")
  is_running := true

  @(private="file")
  raw_input, last_raw_input : struct {
    win_close : bool,

    key_esc : bool,
    key_enter : bool,
    key_w : bool,
    key_a : bool,
    key_s : bool,
    key_d : bool,
    key_z : bool,
    key_q : bool,
    key_h : bool,
    key_t : bool,
    key_g : bool,
    key_x : bool,
    key_c : bool,
    key_r : bool,
    key_up : bool,
    key_down : bool,
    key_left : bool,
    key_right : bool,
  }

////////////////////////////////////////////////////////////////////////////////////////////////////

  main :: proc() {
    platform.implementation = win_impl.implementation
    platform.init()

    h_instance := w32.HINSTANCE(w32.GetModuleHandleW(nil))
    if h_instance == nil {
      crash("Could not get hInstance")
    }

    window_style := w32.WS_OVERLAPPED | w32.WS_CAPTION | w32.WS_SYSMENU | w32.WS_MINIMIZEBOX | w32.WS_MAXIMIZEBOX | w32.WS_THICKFRAME
    window_rect := w32.RECT{ 0, 0, 960, 700 }
    w32.AdjustWindowRectEx(&window_rect, window_style, true, 0)
    window_width := window_rect.right - window_rect.left
    window_height := window_rect.bottom - window_rect.top

    window_class := w32.WNDCLASSW{
      w32.CS_VREDRAW | w32.CS_HREDRAW | w32.CS_OWNDC,
      window_callback,
      {}, {},
      h_instance,
      {}, {}, {}, nil,
      w32.utf8_to_wstring("window class"),
    }
    if w32.RegisterClassW(&window_class) == 0 {
      crash("Could not register window class")
    }

    window := w32.CreateWindowExW({}, window_class.lpszClassName, w32.utf8_to_wstring(GAME_NAME), window_style | w32.WS_VISIBLE, w32.CW_USEDEFAULT, w32.CW_USEDEFAULT, window_width, window_height, nil, nil, h_instance, nil)
    if window == nil {
      fmt.eprintln(w32.GetLastError())
      crash("Could not create window")
    }
    defer w32.DestroyWindow(window)

    accelerators := LoadAcceleratorsW(h_instance, w32.utf8_to_wstring("accelerators"))

    input : game.Input
    game.init_game()
    last_tick_time := time.tick_now()

    msg : w32.MSG
    for is_running && game.is_running {
      tick_time := time.tick_now()
      defer last_tick_time = tick_time
      raw_input.win_close = false

      for w32.PeekMessageW(&msg, nil, 0, 0, w32.PM_REMOVE) {
        if TranslateAcceleratorW(msg.hwnd, accelerators, &msg) == 0
        {
          w32.TranslateMessage(&msg)
          w32.DispatchMessageW(&msg)
        }
      }

      input.delta_time = time.duration_seconds(time.tick_diff(last_tick_time, tick_time))
      input.close_window = raw_input.win_close
      input.esc_press = raw_input.key_esc && !last_raw_input.key_esc
      input.enter_press = raw_input.key_enter && !last_raw_input.key_enter
      input.undo_press = raw_input.key_x && !last_raw_input.key_x
      input.redo_press = raw_input.key_c && !last_raw_input.key_c
      input.reset_press = raw_input.key_r && !last_raw_input.key_r
      // arrows  Any
      // WASD    QWERTY
      // wHTG    Workman
      // ZQsd    AZERTY
      input.up_press = raw_input.key_up && !last_raw_input.key_up ||
                       raw_input.key_w && !last_raw_input.key_w ||
                       raw_input.key_z && !last_raw_input.key_z
      input.left_press = raw_input.key_left && !last_raw_input.key_left ||
                       raw_input.key_a && !last_raw_input.key_a ||
                       raw_input.key_h && !last_raw_input.key_h ||
                       raw_input.key_q && !last_raw_input.key_q
      input.left_press = raw_input.key_left && !last_raw_input.key_left ||
                       raw_input.key_a && !last_raw_input.key_a ||
                       raw_input.key_h && !last_raw_input.key_h ||
                       raw_input.key_q && !last_raw_input.key_q
      input.down_press = raw_input.key_down && !last_raw_input.key_down ||
                       raw_input.key_s && !last_raw_input.key_s ||
                       raw_input.key_t && !last_raw_input.key_t
      input.right_press = raw_input.key_right && !last_raw_input.key_right ||
                       raw_input.key_d && !last_raw_input.key_d ||
                       raw_input.key_g && !last_raw_input.key_g
      last_raw_input = raw_input

      game.update(input)
      game.draw()

      w32.SwapBuffers(w32.GetDC(window))
    }
  }

////////////////////////////////////////////////////////////////////////////////////////////////////

  window_callback :: proc "stdcall" (window : w32.HWND, msg : w32.UINT, w_param : w32.WPARAM, l_param : w32.LPARAM) -> w32.LRESULT {
    @static s_ctx : runtime.Context
    if s_ctx.allocator.procedure == nil {
      s_ctx = runtime.default_context()
    }
    context = s_ctx

    switch msg {
      case w32.WM_CREATE:
        hdc := w32.GetDC(window)
        if hdc == nil {
          crash("Could not get device context")
        }
        pix_format_desc := w32.PIXELFORMATDESCRIPTOR {
          size_of(w32.PIXELFORMATDESCRIPTOR), // nSize: WORD,
           1, // nVersion: WORD,
          w32.PFD_DOUBLEBUFFER | w32.PFD_DRAW_TO_WINDOW | w32.PFD_SUPPORT_OPENGL, // dwFlags: DWORD,
          w32.PFD_TYPE_RGBA, // iPixelType: BYTE,
          32, // cColorBits: BYTE,
           0, // cRedBits: BYTE,
           0, // cRedShift: BYTE,
           0, // cGreenBits: BYTE,
           0, // cGreenShift: BYTE,
           0, // cBlueBits: BYTE,
           0, // cBlueShift: BYTE,
           0, // cAlphaBits: BYTE,
           0, // cAlphaShift: BYTE,
           0, // cAccumBits: BYTE,
           0, // cAccumRedBits: BYTE,
           0, // cAccumGreenBits: BYTE,
           0, // cAccumBlueBits: BYTE,
           0, // cAccumAlphaBits: BYTE,
          32, // cDepthBits: BYTE,
           0, // cStencilBits: BYTE,
           0, // cAuxBuffers: BYTE,
           0, // iLayerType: BYTE,
           0, // bReserved: BYTE,
           0, // dwLayerMask: DWORD,
           0, // dwVisibleMask: DWORD,
           0, // dwDamageMask: DWORD,
        }
        pix_format := w32.ChoosePixelFormat(hdc, &pix_format_desc)
        if pix_format == 0 {
          crash("Could not find usable pixel format")
        }
        if !w32.SetPixelFormat(hdc, pix_format, &pix_format_desc) {
          crash("Could not set pixel format")
        }

        boot_strap_ctx := w32.wglCreateContext(hdc)
        if boot_strap_ctx == nil {
          crash("Could not create OpenGL context")
        }
        if !w32.wglMakeCurrent(hdc, boot_strap_ctx) {
          crash("Could not switch to OpenGL context")
        }

        GL_MAJOR :: 4
        GL_MINOR :: 6
        attribs := [?]i32 {
          w32.WGL_CONTEXT_MAJOR_VERSION_ARB, GL_MAJOR,
          w32.WGL_CONTEXT_MINOR_VERSION_ARB, GL_MINOR,
          w32.WGL_CONTEXT_PROFILE_MASK_ARB, w32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
          0,
        }
        gl_ctx := (w32.CreateContextAttribsARBType)(w32.wglGetProcAddress("wglCreateContextAttribsARB"))(hdc, nil, &attribs[0])

        w32.wglMakeCurrent(hdc, boot_strap_ctx)
        w32.wglDeleteContext(boot_strap_ctx)

        w32.wglMakeCurrent(hdc, gl_ctx)

        (w32.SwapIntervalEXTType)(w32.wglGetProcAddress("wglSwapIntervalEXT"))(1)
        @static opengl32 : w32.HMODULE
        if opengl32 == nil {
          opengl32 = w32.GetModuleHandleW(w32.utf8_to_wstring("opengl32.dll"))
        }
        gl.load_up_to(GL_MAJOR, GL_MINOR, proc(ptr : rawptr, name : cstring) {
          ptr := (^rawptr)(ptr)
          ptr^ = w32.wglGetProcAddress(name)
          if transmute(int)(ptr^) == 0 {
            ptr^ = w32.GetProcAddress(opengl32, name)
          }
        })
        graphics.implementation = gl_impl.implementation
        graphics.init()
        rect : w32.RECT
        if w32.GetClientRect(window, &rect) {
          width := rect.right - rect.left
          height := rect.bottom - rect.top
          gl.Viewport(0, 0, width, height)
          game.display_resize(int(width), int(height))
        }
        return 0
      case w32.WM_SETCURSOR:
        default_result := w32.DefWindowProcW(window, msg, w_param, l_param)
        if default_result == 0 {
          @static default_cursor : w32.HCURSOR
          if default_cursor == {} {
            default_cursor = w32.LoadCursorA(nil, w32.IDC_ARROW)
          }
          w32.SetCursor(default_cursor)
          return 1
        }
        return default_result
      case w32.WM_KEYDOWN:
        switch w_param {
          case w32.VK_ESCAPE:
            raw_input.key_esc = true
          case w32.VK_RETURN:
            raw_input.key_enter = true
          case w32.VK_W:
            raw_input.key_w = true
          case w32.VK_A:
            raw_input.key_a = true
          case w32.VK_S:
            raw_input.key_s = true
          case w32.VK_D:
            raw_input.key_d = true
          case w32.VK_Z:
            raw_input.key_z = true
          case w32.VK_Q:
            raw_input.key_q = true
          case w32.VK_H:
            raw_input.key_h = true
          case w32.VK_T:
            raw_input.key_t = true
          case w32.VK_G:
            raw_input.key_g = true
          case w32.VK_X:
            raw_input.key_x = true
          case w32.VK_C:
            raw_input.key_c = true
          case w32.VK_R:
            raw_input.key_r = true
          case w32.VK_UP:
            raw_input.key_up = true
          case w32.VK_DOWN:
            raw_input.key_down = true
          case w32.VK_LEFT:
            raw_input.key_left = true
          case w32.VK_RIGHT:
            raw_input.key_right = true
        }
        return 0
      case w32.WM_KEYUP:
        switch w_param {
          case w32.VK_ESCAPE:
            raw_input.key_esc = false
          case w32.VK_RETURN:
            raw_input.key_enter = false
          case w32.VK_W:
            raw_input.key_w = false
          case w32.VK_A:
            raw_input.key_a = false
          case w32.VK_S:
            raw_input.key_s = false
          case w32.VK_D:
            raw_input.key_d = false
          case w32.VK_Z:
            raw_input.key_z = false
          case w32.VK_Q:
            raw_input.key_q = false
          case w32.VK_H:
            raw_input.key_h = false
          case w32.VK_T:
            raw_input.key_t = false
          case w32.VK_G:
            raw_input.key_g = false
          case w32.VK_X:
            raw_input.key_x = false
          case w32.VK_C:
            raw_input.key_c = false
          case w32.VK_R:
            raw_input.key_r = false
          case w32.VK_UP:
            raw_input.key_up = false
          case w32.VK_DOWN:
            raw_input.key_down = false
          case w32.VK_LEFT:
            raw_input.key_left = false
          case w32.VK_RIGHT:
            raw_input.key_right = false
        }
        return 0
      case w32.WM_CLOSE:
        raw_input.win_close = true
        return 0
      case w32.WM_QUIT:
        is_running = false
        return 0
      case w32.WM_GETMINMAXINFO:
        mmi := (w32.LPMINMAXINFO)((uintptr)(l_param))
        mmi.ptMinTrackSize.x = 640
        mmi.ptMinTrackSize.y = 480
        return 0
      case w32.WM_SIZE:
        rect : w32.RECT
        if w32.GetClientRect(window, &rect) {
          width := rect.right - rect.left
          height := rect.bottom - rect.top
          gl.Viewport(0, 0, width, height)
          game.display_resize(int(width), int(height))
        }
        return 0
      case w32.WM_DESTROY:
        w32.PostQuitMessage(0)
        return 0
      case:
        return w32.DefWindowProcW(window, msg, w_param, l_param)
    }
  }

  crash :: proc(msg : string) {
    fmt.eprintln(msg)
    w32.MessageBoxW(nil, w32.utf8_to_wstring(msg), w32.utf8_to_wstring(GAME_NAME), w32.MB_OK | w32.MB_ICONERROR)
    os.exit(1)
  }
