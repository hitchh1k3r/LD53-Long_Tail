package build

import "core:fmt"
import "core:mem"
import "core:odin/ast"
import "core:os"
import "core:prof/spall"
import "core:runtime"
import "core:strings"
import "core:time"

import "build:beard"
import "build:html_generators"
import "build:message_generators"
import "build:meta"
import "build:popen"
import "build:project_errors"
import "build:resources"

when ODIN_OS == .Windows {

  import "core:sys/windows"

} else {

  import "core:sys/unix"

}

DEBUG_COMMANDS :: false

// Enums ///////////////////////////////////////////////////////////////////////////////////////////

  TargetPlatform :: enum {
    Windows_x64,
    Linux_x64,
    MacOS_arm64,
    WASM_32,
  }

  SystexAPI :: enum {
    Win32,
    X11,
    Wayland,
    Cocoa,
    Javascript,
  }

  GraphicsLib :: enum {
    Direct3D,
    OpenGL,
    WebGL,
    Metal,
    Vulkan,
  }

  Mode :: enum {
    Build,
    Run,
  }

  BuildType :: enum {
    Fast,
    Debug,
    Release,
  }

  target_platform_args :: [TargetPlatform]string {
    .Windows_x64 = "win64",
    .Linux_x64 = "linux64",
    .MacOS_arm64 = "macos_arm64",
    .WASM_32 = "wasm32",
  }

  system_api_args :: [SystexAPI]string {
    .Win32 = "win32",
    .X11 = "x11",
    .Wayland = "wayland",
    .Cocoa = "cocoa",
    .Javascript = "js",
  }

  graphics_lib_args :: [GraphicsLib]string {
    .Direct3D = "d3d",
    .OpenGL = "opengl",
    .WebGL = "webgl",
    .Metal = "metal",
    .Vulkan = "vulkan",
  }

  mode_args :: [Mode]string {
    .Build = "build",
    .Run = "run",
  }

  build_type_args :: [BuildType]string {
    .Fast = "fast",
    .Debug = "debug",
    .Release = "release",
  }

// Commands ////////////////////////////////////////////////////////////////////////////////////////

  Command :: union {
    Print,
    Log,

    Make_Dir,
    Delete_Dir,
    Clean_Dir,
    Copy_File,
    Make_Dir_Link,
    Make_File_Link,

    Exec,

    Check_For_Errors,
    Generate_ETW_Messages,
    Clean_Compile_Resources,
    Update_Resources,

    Generate_Javascript,
    Generate_HTML,

    Run_Build,
  }

  Print :: struct {
    str : string,
  }
  Log :: struct {
    verbose : bool,
  }

  Make_Dir :: struct {
    path : string,
  }
  Delete_Dir :: struct {
    path : string,
  }
  Clean_Dir :: struct {
    path : string,
  }
  Copy_File :: struct {
    src_path : string,
    dst_path : string,
  }
  Make_Dir_Link :: struct {
    link_path : string,
    target_path : string,
  }
  Make_File_Link :: struct {
    link_path : string,
    target_path : string,
  }

  Exec :: struct {
    cmd : string,
    expected_exit_code : int,
    flags : bit_set[enum { Fail_On_Output }],
  }

  Check_For_Errors :: struct {}
  Generate_ETW_Messages :: struct {}
  Clean_Compile_Resources :: struct {}
  Update_Resources :: struct {}

  Generate_Javascript :: struct {
    wasm_path : string,
    webgl_version : html_generators.WebGL_Version,
    output_path : string,
  }
  Generate_HTML :: struct {
    title : string,
    javascript_path : string,
    output_path : string,
  }

  Run_Build :: struct {
    exe_path : string,
  }

// Main ////////////////////////////////////////////////////////////////////////////////////////////

  @(private="file")
  spall_ctx : spall.Context

  @(private="file")
  spall_buffer : spall.Buffer

  @(deferred_none=PROFILE_END)
  PROFILE :: proc(name : string, args := "", location := #caller_location) {
    PROFILE_START(name, args, location)
  }

  PROFILE_START :: proc(name : string, args := "", location := #caller_location) {
    spall._buffer_begin(&spall_ctx, &spall_buffer, name, args, location)
  }

  PROFILE_END :: proc() {
    spall._buffer_end(&spall_ctx, &spall_buffer)
  }

  main :: proc() {
    spall_ctx = spall.context_create("build.spall")
    defer spall.context_destroy(&spall_ctx)

    buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
    spall_buffer = spall.buffer_create(buffer_backing)
    defer spall.buffer_destroy(&spall_ctx, &spall_buffer)

    PROFILE(#procedure)

    beard._PROFILE_START = PROFILE_START
    beard._PROFILE_END = PROFILE_END
    html_generators._PROFILE_START = PROFILE_START
    html_generators._PROFILE_END = PROFILE_END
    message_generators._PROFILE_START = PROFILE_START
    message_generators._PROFILE_END = PROFILE_END
    meta._PROFILE_START = PROFILE_START
    meta._PROFILE_END = PROFILE_END
    project_errors._PROFILE_START = PROFILE_START
    project_errors._PROFILE_END = PROFILE_END
    resources._PROFILE_START = PROFILE_START
    resources._PROFILE_END = PROFILE_END

    target_platform : TargetPlatform
    system_api : SystexAPI
    graphics_lib : GraphicsLib
    mode : Mode
    build_type : BuildType

    PROFILE_START("process_args:")
    process_args:
    {
      if len(os.args) == 6 {
        valid := 0
        for str, val in target_platform_args {
          if str == os.args[1] {
            target_platform = val
            valid += 1
            break
          }
        }
        for str, val in system_api_args {
          if str == os.args[2] {
            system_api = val
            valid += 1
            break
          }
        }
        for str, val in graphics_lib_args {
          if str == os.args[3] {
            graphics_lib = val
            valid += 1
            break
          }
        }
        for str, val in mode_args {
          if str == os.args[4] {
            mode = val
            valid += 1
            break
          }
        }
        for str, val in build_type_args {
          if str == os.args[5] {
            build_type = val
            valid += 1
            break
          }
        }
        if valid == 5 {
          // ARGS OKAY:
          break process_args
        }
      }
      // ARGS FAIL:
      fmt.eprint("Usage:", os.args[0], "[")
      i := 0
      for str in target_platform_args {
        defer i += 1
        if i > 0 {
          fmt.eprint(",")
        }
        fmt.eprint(str)
      }
      fmt.eprint("] [")
      i = 0
      for str in system_api_args {
        defer i += 1
        if i > 0 {
          fmt.eprint(",")
        }
        fmt.eprint(str)
      }
      fmt.eprint("] [")
      i = 0
      for str in graphics_lib_args {
        defer i += 1
        if i > 0 {
          fmt.eprint(",")
        }
        fmt.eprint(str)
      }
      fmt.eprint("] [")
      i = 0
      for str in mode_args {
        defer i += 1
        if i > 0 {
          fmt.eprint(",")
        }
        fmt.eprint(str)
      }
      fmt.eprint("] [")
      i = 0
      for str in build_type_args {
        defer i += 1
        if i > 0 {
          fmt.eprint(",")
        }
        fmt.eprint(str)
      }
      fmt.eprint("]\n")
      os.exit(1)
    }
    PROFILE_END()

    ALWAYS_FLAGS :: "-warnings-as-errors -ignore-unknown-attributes -collection:project=./src/"

    PROFILE_START("build_commands:")
    commands : []Command
    switch {

      case:
        fmt.eprintln("Unknown configuration:", target_platform, system_api, graphics_lib)
        os.exit(1)

      case target_platform == .Windows_x64 && system_api == .Win32 && graphics_lib == .OpenGL:
        SRC :: "src/windows_64_win32_opengl.odin -file"
        EXE :: "artifacts/windows64_win32_opengl/Long Tail.exe"
        FLAGS :: "-out:\""+EXE+"\""
        switch build_type {
          case .Fast:
            commands = {
                  Log{ false },
              Make_Dir{ "build" },
              Make_Dir{ "artifacts" },
              Make_Dir{ "artifacts/resources" },
              Make_Dir{ "artifacts/windows64_win32_opengl" },
                  Log{ true },
              Update_Resources{},
                  Log{ false },
              Make_File_Link{ "artifacts/resources/asset.pak", "artifacts/windows64_win32_opengl/asset.pak" },
                  Log{ true },
              Generate_ETW_Messages{},
              Check_For_Errors{},
              Exec{ "odin build " + SRC + " -o:minimal " + FLAGS + " " + ALWAYS_FLAGS, 0, {.Fail_On_Output} },
              nil, // run placeholder
            }
          case .Debug:
            commands = {
                  Log{ false },
              Make_Dir{ "build" },
              Make_Dir{ "artifacts" },
              Make_Dir{ "artifacts/resources" },
              Make_Dir{ "artifacts/windows64_win32_opengl" },
                  Log{ true },
              Update_Resources{},
                  Log{ false },
              Make_File_Link{ "artifacts/resources/asset.pak", "artifacts/windows64_win32_opengl/asset.pak" },
                  Log{ true },
              Generate_ETW_Messages{},
              Check_For_Errors{},
              Exec{ "odin build " + SRC + " -o:none -debug " + FLAGS + " " + ALWAYS_FLAGS, 0, {.Fail_On_Output} },
              nil, // run placeholder
            }
          case .Release:
            commands = {
              Make_Dir{ "build" },
              Make_Dir{ "artifacts" },
              Make_Dir{ "artifacts/resources" },
              Make_Dir{ "artifacts/windows64_win32_opengl" },
              Clean_Dir{ "artifacts/windows64_win32_opengl" },
              Clean_Compile_Resources{},
              Copy_File{ "artifacts/resources/asset.pak", "artifacts/windows64_win32_opengl/asset.pak" },
              Generate_ETW_Messages{},
              Check_For_Errors{},
              Exec{ "odin build " + SRC + " -o:speed -strict-style -vet -subsystem:windows " + FLAGS + " " + ALWAYS_FLAGS, 0, {.Fail_On_Output} },
              nil, // run placeholder
            }
        }
        if mode == .Run {
          commands[len(commands)-1] = Run_Build{ EXE }
        }

      case target_platform == .WASM_32 && system_api == .Javascript && graphics_lib == .WebGL:
        HTML_TITLE :: "Jellbreak 2023"
        WEBGL_VERSION :: html_generators.WebGL_Version.WebGL_2
        SRC :: "src/wasm_js_webgl.odin -file"
        WASM_FULL :: "artifacts/wasm_js_webgl/_temp/full.wasm"
        WASM_OPT :: "artifacts/wasm_js_webgl/_temp/opt.wasm"
        JS_FULL :: "artifacts/wasm_js_webgl/_temp/full.js"
        JS_OPT :: "artifacts/wasm_js_webgl/_temp/opt.js"
        HTML :: "artifacts/wasm_js_webgl/index.html"
        FLAGS :: "-out:\""+WASM_FULL+"\" -target:js_wasm32 -ignore-vs-search -no-crt -extra-linker-flags:\"--import-memory --lto-O3 --gc-sections --strip-all --export=__heap_base --export=__data_end\""
        switch build_type {
          case .Fast:
            commands = {
                  Log{ false },
              Make_Dir{ "artifacts" },
              Make_Dir{ "artifacts/resources" },
              Make_Dir{ "artifacts/wasm_js_webgl" },
              Make_Dir{ "artifacts/wasm_js_webgl/_temp" },
                  Log{ true },
              Update_Resources{},
                  Log{ false },
              Make_File_Link{ "artifacts/resources/asset.pak", "artifacts/wasm_js_webgl/asset.pak" },
                  Log{ true },
              Generate_ETW_Messages{},
              Check_For_Errors{},
              Exec{ "odin build " + SRC + " -o:minimal " + FLAGS + " " + ALWAYS_FLAGS, 0, {.Fail_On_Output} },
              Generate_Javascript{ WASM_FULL, WEBGL_VERSION, JS_FULL },
              Generate_HTML{ HTML_TITLE, JS_FULL, HTML },
            }
          case .Debug:
            commands = {
                  Log{ false },
              Make_Dir{ "artifacts" },
              Make_Dir{ "artifacts/resources" },
              Make_Dir{ "artifacts/wasm_js_webgl" },
              Make_Dir{ "artifacts/wasm_js_webgl/_temp" },
                  Log{ true },
              Update_Resources{},
                  Log{ false },
              Make_File_Link{ "artifacts/resources/asset.pak", "artifacts/wasm_js_webgl/asset.pak" },
                  Log{ true },
              Generate_ETW_Messages{},
              Check_For_Errors{},
              Exec{ "odin build " + SRC + " -o:none -debug " + FLAGS + " " + ALWAYS_FLAGS, 0, {.Fail_On_Output} },
              Generate_Javascript{ WASM_FULL, WEBGL_VERSION, JS_FULL },
              Generate_HTML{ HTML_TITLE, JS_FULL, HTML },
            }
          case .Release:
            when ODIN_OS == .Windows {
              HOST_EXTENSION :: "win64.exe"
            } else when ODIN_OS == .Linux {
              HOST_EXTENSION :: "linux-x64"
            } else when ODIN_OS == .Darwin && ODIN_ARCH == .amd64 {
              HOST_EXTENSION :: "macos-x64"
            } else when ODIN_OS == .Darwin && ODIN_ARCH == .arm64 {
              HOST_EXTENSION :: "macos-arm64"
            }
            commands = {
              Make_Dir{ "artifacts" },
              Make_Dir{ "artifacts/resources" },
              Make_Dir{ "artifacts/wasm_js_webgl" },
              Clean_Dir{ "artifacts/wasm_js_webgl" },
              Make_Dir{ "artifacts/wasm_js_webgl/_temp" },
              Clean_Compile_Resources{},
              Make_File_Link{ "artifacts/resources/asset.pak", "artifacts/wasm_js_webgl/asset.pak" },
              Generate_ETW_Messages{},
              Check_For_Errors{},
              Exec{ "odin build " + SRC + " -o:size " + FLAGS + " " + ALWAYS_FLAGS, 0, {.Fail_On_Output} },
              Exec{ "build\\external_tools\\wasm-opt-" + HOST_EXTENSION + " -Oz --zero-filled-memory --strip-producers \"" + WASM_FULL + "\" -o \"" + WASM_OPT + "\"", 0, {} },
              Generate_Javascript{ WASM_OPT, WEBGL_VERSION, JS_FULL },
              // We can detect \nX error(s), in the output, it seems to return 0 on error :(
              Exec{ "java -jar \"build/external_tools/closure-compiler.jar\" --js \"" + JS_FULL + "\" --js_output_file \"" + JS_OPT + "\" --externs \"build/external_resources/externs.js\" --compilation_level ADVANCED --language_out STABLE", 0, {} },
              Generate_HTML{ HTML_TITLE, JS_OPT, HTML },
              Delete_Dir{ "artifacts/wasm_js_webgl/_temp" },
            }
        }

    }
    PROFILE_END()

    ////////////////////////////////////////////////////////////////////////////////////////////////

    root_declarations : map[string]meta.MetaDecl
    all_files_ast : map[string]^ast.File

    timings : map[string]string
    time_keys : [dynamic]string

    first_nsec := time.now()._nsec
    now_nsec := first_nsec
    last_nsec := now_nsec
    log := true
    run_cmd := ""
    for cmd in commands {
      free_all(context.temp_allocator)
      PROFILE(fmt.tprintf("process(%v)", cmd))
      last_nsec = now_nsec
      can_log := log && cmd != nil
      timing_name := ""
      do_cmd:
      switch cmd in cmd {

        case Print:
          fmt.println(cmd.str)

        case Log:
          when !DEBUG_COMMANDS {
            log = cmd.verbose
          }

        case Make_Dir:
          if log do fmt.print(seperator_string(fmt.tprintf("Make %v", cmd.path)))
          os.make_directory(cmd.path)

        case Delete_Dir:
          if log do fmt.print(seperator_string(fmt.tprintf("Delete %v", cmd.path)))
          when ODIN_OS == .Windows {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("rd /s /q \"%v\" 2>&1", cmd.path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("rd /s /q \"%v\" 2>&1", cmd.path), context.temp_allocator))
            }
          } else {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("rm -rf \"%v\" 2>&1", cmd.path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("rm -rf \"%v\" 2>&1", cmd.path), context.temp_allocator))
            }
          }

        case Clean_Dir:
          path := platform_path(cmd.path)
          defer delete(path)
          if log do fmt.print(seperator_string(fmt.tprintf("Clean %v", path)))
          when ODIN_OS == .Windows {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("for /f %%i in ('dir /s /b \"%v\"') do rd /s /q \"%%i\" 2>&1", path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("rd /s /q \"%v\\*\" 2>&1", path), context.temp_allocator))
            }
          } else {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("rm -rf \"%v/*\" 2>&1", path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("rm -rf \"%v/*\" 2>&1", path), context.temp_allocator))
            }
          }

        case Copy_File:
          src_path := platform_path(cmd.src_path)
          dst_path := platform_path(cmd.dst_path)
          defer delete(src_path)
          defer delete(dst_path)
          if log do fmt.print(seperator_string(fmt.tprintf("Copy %v -> %v", src_path, dst_path)))
          PROFILE_START("read_file()")
          bytes, _ := os.read_entire_file(src_path, context.temp_allocator)
          PROFILE_END()
          PROFILE_START("write_file()")
          os.write_entire_file(dst_path, bytes)
          PROFILE_END()

        case Make_Dir_Link:
          link_path := platform_path(cmd.link_path)
          target_path := platform_path(cmd.target_path)
          defer delete(link_path)
          defer delete(target_path)
          if log do fmt.print(seperator_string(fmt.tprintf("Linking %v -> %v", link_path, target_path)))
          when ODIN_OS == .Windows {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("mklink /J \"%v\" \"%v\" 2>&1", target_path, link_path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("mklink /J \"%v\" \"%v\" 2>&1", target_path, link_path), context.temp_allocator))
            }
          } else {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("ln -s \"%v\" \"%v\" 2>&1", link_path, target_path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("ln -s \"%v\" \"%v\" 2>&1", link_path, target_path), context.temp_allocator))
            }
          }

        case Make_File_Link:
          link_path := platform_path(cmd.link_path)
          target_path := platform_path(cmd.target_path)
          defer delete(link_path)
          defer delete(target_path)
          if log do fmt.print(seperator_string(fmt.tprintf("Linking %v -> %v", link_path, target_path)))
          when ODIN_OS == .Windows {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("mklink /H \"%v\" \"%v\" 2>&1", target_path, link_path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("mklink /H \"%v\" \"%v\" 2>&1", target_path, link_path), context.temp_allocator))
            }
          } else {
            when DEBUG_COMMANDS {
              fmt.println(popen.exec(strings.clone_to_cstring(fmt.tprintf("ln -s \"%v\" \"%v\" 2>&1", link_path, target_path), context.temp_allocator)))
            } else {
              popen.exec(strings.clone_to_cstring(fmt.tprintf("ln -s \"%v\" \"%v\" 2>&1", link_path, target_path), context.temp_allocator))
            }
          }

        case Exec:
          if log {
            fmt.print(seperator_string("Execute Command"))
            fmt.printf("  > %v\n", cmd.cmd)
          }
          timing_name = fmt.aprintf("`%v...`", cmd.cmd[0:min(len(cmd.cmd), 21)])
          std_out, exit_code := popen.exec(strings.clone_to_cstring(fmt.tprintf("%v 2>&1", cmd.cmd), context.temp_allocator))
          if log {
            lines := strings.split_lines(std_out)
            defer delete(lines)
            for line, i in lines {
              if i > 0 {
                fmt.print("\n")
              }
              if line != "" {
                fmt.printf("    %v", line)
              }
            }
          }
          if .Fail_On_Output in cmd.flags {
            if std_out != "" {
              fmt.eprintln("failed to run command")
              os.exit(1)
            }
          }
          if cmd.expected_exit_code >= 0 && int(exit_code) != cmd.expected_exit_code {
            fmt.eprintln("failed to run command")
            os.exit(1)
          }

        case Check_For_Errors:
          if log do fmt.print(seperator_string("Checking Project Errors"))
          timing_name = "Check Project Errors"
          if len(root_declarations) == 0 {
            root_declarations, all_files_ast = meta.parse_game()
          }
          project_errors.check_for_errors(all_files_ast)

        case Generate_ETW_Messages:
          if log do fmt.print(seperator_string("Generating Messages"))
          timing_name = "Generate Messages"
          if len(root_declarations) == 0 {
            root_declarations, all_files_ast = meta.parse_game()
          }
          message_generators.init_world()
          message_generators.gen_entities(root_declarations)
          message_generators.gen_tiles(root_declarations)
          message_generators.gen_world()

        case Clean_Compile_Resources:
          if log do fmt.print(seperator_string("Compile Resources"))
          timing_name = "Compile Resources"
          resources.gen_resources(true)

        case Update_Resources:
          if log do fmt.print(seperator_string("Update Resources"))
          timing_name = "Update Resources"
          resources.gen_resources(false)

        case Generate_Javascript:
          if log do fmt.print(seperator_string("Generating Javascript"))
          timing_name = "Generate Javascript"
          html_generators.gen_javascript(cmd.wasm_path, cmd.webgl_version, cmd.output_path)

        case Generate_HTML:
          if log do fmt.print(seperator_string("Generating HTML"))
          timing_name = "Generate HTML"
          html_generators.gen_html(cmd.title, cmd.javascript_path, cmd.output_path)

        case Run_Build:
          run_cmd = cmd.exe_path
          can_log = false

      }
      now_nsec = time.now()._nsec
      if timing_name != "" {
        append(&time_keys, timing_name)
        timings[timing_name] = time_string(now_nsec - last_nsec, context.allocator)
      }

      if log && can_log {
        if timing_name != "" {
          fmt.printf("  ...complete %v\n", strings.trim_space(timings[timing_name]))
        } else {
          fmt.printf("  ...complete\n")
        }
      }
    }
    fmt.print("\n=|= Build Timing ===============================================|=\n")
    for timing in time_keys {
      fmt.printf(" | % 26v %v |\n", timing, timings[timing])
    }
    fmt.println("=|==============================================================|=")
    fmt.printf(" |                      Total %v |\n", time_string(now_nsec - first_nsec))
    fmt.println("=|==============================================================|=")

    if run_cmd != "" {
      fmt.print(seperator_string("Running Artifact"))
      fmt.print("\n")
      popen.exec(strings.clone_to_cstring(fmt.tprintf("\"%v\"", run_cmd), context.temp_allocator), context.temp_allocator, false)
    }
  }

// Utilities ///////////////////////////////////////////////////////////////////////////////////////

  time_string :: proc(nsec : i64, allocator := context.temp_allocator) -> string {
    nsec := nsec

    hr := nsec / i64(time.Hour)
    nsec -= hr * i64(time.Hour)
    min := nsec / i64(time.Minute)
    nsec -= min * i64(time.Minute)
    sec := nsec / i64(time.Second)
    nsec -= sec * i64(time.Second)
    msec := nsec / i64(time.Millisecond)
    nsec -= msec * i64(time.Millisecond)
    usec := nsec / i64(time.Microsecond)
    nsec -= usec * i64(time.Microsecond)

    context.allocator = allocator
    if hr > 0 {
      return fmt.aprintf("% 2vhr % 2vmin % 2vs % 3vms % 3v0μs % 3vns", hr, min, sec, msec, usec, nsec)
    } else if min > 0 {
      return fmt.aprintf("     % 2vmin % 2vs % 3vms % 3v0μs % 3vns", min, sec, msec, usec, nsec)
    } else {
      return fmt.aprintf("           % 2vs % 3vms % 3v0μs % 3vns", sec, msec, usec, nsec)
    }
  }

  SEPERATOR :: "=================================================================="

  seperator_string :: proc(title : string, allocator := context.temp_allocator) -> string {
    seperator := make([]u8, len(SEPERATOR)+2)
    for i in 0..<len(seperator) {
      seperator[i] = '='
    }
    for i in -1..=min(len(title), len(SEPERATOR)-3) {
      if i < 0 || i >= len(title) {
        seperator[i+3] = ' '
      } else {
        seperator[i+3] = title[i]
      }
    }
    seperator[0] = '\n'
    seperator[len(seperator)-1] = '\n'
    return string(seperator)
  }

  platform_path :: proc(path : string, allocator := context.allocator) -> string {
    path := transmute([]u8)path
    bytes := make([]u8, len(path))
    for c, i in path {
      when ODIN_OS == .Windows {
        if c == '/' {
          bytes[i] = '\\'
        } else {
          bytes[i] = c
        }
      } else {
        if c == '\\' {
          bytes[i] = '/'
        } else {
          bytes[i] = c
        }
      }
    }
    return string(bytes)
  }