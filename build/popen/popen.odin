package popen

import "core:fmt"
import "core:strings"
import "core:c/libc"

when ODIN_OS == .Windows {
  foreign import lib "system:libcmt.lib"

  @(default_calling_convention="c")
  foreign lib {
    @(link_name="_popen")
    popen :: proc(command, mode: cstring) -> ^libc.FILE ---
    @(link_name="_pclose")
    pclose :: proc(stream : ^libc.FILE) -> i32 ---
  }
} else {
  foreign import lib "system:c"

  @(default_calling_convention="c")
  foreign lib {
    popen :: proc(command, mode: cstring) -> ^libc.FILE ---
    pclose :: proc(stream : ^libc.FILE) -> i32 ---
  }
}

/*
main :: proc() {
  os.change_directory("C:/Users/HitchH1k3r/Documents/Development/Odin/Gel Break 2022/")

  ver_bld : strings.Builder

  branch := exec("git rev-parse --abbrev-ref HEAD")
  rev := exec("git rev-list --count HEAD")

  strings.write_string(&ver_bld, rev[:len(rev)-1])
  strings.write_string(&ver_bld, "-")
  strings.write_string(&ver_bld, branch[:len(branch)-1])

  fmt.println(strings.to_string(ver_bld))
}
*/

exec :: proc(cmd : cstring, allocator := context.temp_allocator, capture_std_out := true) -> (stdout : string, exit_code : u8) {
  cmd_output := popen(cmd, "r")
  out_bld := strings.builder_make_none(allocator)
  defer strings.builder_destroy(&out_bld)
  buffer : [1024]u8
  if capture_std_out {
    for libc.fgets(&buffer[0], len(buffer), cmd_output) != nil {
      strings.write_string(&out_bld, string(transmute(cstring)(&buffer[0])))
    }
  } else {
    for libc.fgets(&buffer[0], len(buffer), cmd_output) != nil {
      fmt.print(transmute(cstring)(&buffer[0]))
    }
  }
  exit_status := pclose(cmd_output)
  return strings.to_string(out_bld), u8((exit_status & 0xFF00) >> 8)
}
