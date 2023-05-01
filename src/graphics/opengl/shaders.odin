package opengl

import "core:fmt"

import gl "vendor:OpenGL"

ShaderProgram :: struct {
  program_id : u32,
  uniforms : gl.Uniforms,
}

program_from_source :: proc(vs_source, fs_source: string, loc := #caller_location) -> (program : ShaderProgram, ok : bool) {
  using program
  if program_id, ok = gl.load_shaders_source(vs_source, fs_source); ok {
    uniforms = gl.get_uniforms_from_program(program_id)
  } else {
    fmt.eprintln("Failed to create GLSL program at", loc)
  }
  return
}

cleanup_program :: proc(using program : ShaderProgram) {
  gl.DeleteProgram(program_id)
  delete(uniforms)
}

use_program :: proc(using program : ShaderProgram) {
  gl.UseProgram(program_id)
}
