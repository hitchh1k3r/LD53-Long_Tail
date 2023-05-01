package graphics_webgl

import "core:fmt"

import "project:platform/wasm/webgl"

ShaderProgram :: struct {
  program_id : webgl.Program,
  uniforms : map[string]i32,
}

program_from_source :: proc(vs_source, fs_source: string, loc := #caller_location) -> (program : ShaderProgram, ok : bool) {
  using program
  if program_id, ok = webgl.CreateProgramFromStrings({ vs_source }, { fs_source }); ok {
  } else {
    fmt.eprintln("Failed to create GLSL program at", loc)
  }
  return
}

cleanup_program :: proc(using program : ShaderProgram) {
  webgl.DeleteProgram(program_id)
}

use_program :: proc(using program : ShaderProgram) {
  webgl.UseProgram(program_id)
}
