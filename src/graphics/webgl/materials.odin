package graphics_webgl

import "project:graphics"
import "project:platform/wasm/webgl"

VERT_ATTRIB_POS_LOC :: 0
VERT_ATTRIB_UV_LOC :: 1
VERT_ATTRIB_NORM_LOC :: 2
VERT_ATTRIB_COLOR_LOC :: 3

// TODO (hitch) 2023-03-13 This is not a great way to store and load shaders, I could easily copy paste the wrong shader in draw functions, and it has not runtime enforcement of all Material types...
material_shaders : map[typeid]ShaderProgram

init_materials :: proc() {
  ok : bool
  // TODO (hitch) 2023-03-07 Error Handling...
  if material_shaders[graphics.MaterialUnlit], ok = program_from_source(UNLIT_VS, UNLIT_FS); ok {
    shader := &material_shaders[graphics.MaterialUnlit]
    shader.uniforms = make(map[string]i32, 4)
    shader.uniforms["u_matrix_view_projection"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_view_projection")
    shader.uniforms["u_matrix_model"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_model")
    shader.uniforms["u_color"] = webgl.GetUniformLocation(shader.program_id, "u_color")
    shader.uniforms["u_texture"] = webgl.GetUniformLocation(shader.program_id, "u_texture")
  } else {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }

  if material_shaders[graphics.MaterialLit], ok = program_from_source(LIT_VS, LIT_FS); ok {
    shader := &material_shaders[graphics.MaterialLit]
    shader.uniforms = make(map[string]i32, 4)
    shader.uniforms["u_matrix_projection"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_projection")
    shader.uniforms["u_matrix_view"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_view")
    shader.uniforms["u_matrix_model"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_model")
    shader.uniforms["u_texture"] = webgl.GetUniformLocation(shader.program_id, "u_texture")
  } else {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }

  if material_shaders[graphics.MaterialTilemap], ok = program_from_source(TILEMAP_VS, TILEMAP_FS); ok {
    shader := &material_shaders[graphics.MaterialTilemap]
    shader.uniforms = make(map[string]i32, 4)
    shader.uniforms["u_matrix_view_projection"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_view_projection")
    shader.uniforms["u_matrix_model"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_model")
    shader.uniforms["u_tilemap"] = webgl.GetUniformLocation(shader.program_id, "u_tilemap")
    shader.uniforms["u_room_tiles"] = webgl.GetUniformLocation(shader.program_id, "u_room_tiles")
  } else {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }

  if material_shaders[graphics.MaterialSprite], ok = program_from_source(SPRITE_VS, SPRITE_FS); ok {
    shader := &material_shaders[graphics.MaterialSprite]
    shader.uniforms = make(map[string]i32, 5)
    shader.uniforms["u_matrix_view_projection"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_view_projection")
    shader.uniforms["u_matrix_model"] = webgl.GetUniformLocation(shader.program_id, "u_matrix_model")
    shader.uniforms["u_sprite_rect"] = webgl.GetUniformLocation(shader.program_id, "u_sprite_rect")
    shader.uniforms["u_color"] = webgl.GetUniformLocation(shader.program_id, "u_color")
    shader.uniforms["u_texture"] = webgl.GetUniformLocation(shader.program_id, "u_texture")
  } else {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }
}

// Unlit Materials /////////////////////////////////////////////////////////////////////////////////

  UNLIT_VS := `#version 300 es
  precision highp float;

  layout(location=0) in vec3 i_position;
  layout(location=1) in vec2 i_uv;
  layout(location=2) in vec3 i_norm;
  layout(location=3) in vec4 i_color;

  uniform mat4 u_matrix_view_projection; // projection * view
  uniform mat4 u_matrix_model;

  out vec2 v2f_uv;
  out vec3 v2f_norm;
  out vec4 v2f_color;

  void main() {
    gl_Position = (u_matrix_view_projection * u_matrix_model) * vec4(i_position, 1.0);
    v2f_uv = i_uv;
    v2f_norm = normalize(u_matrix_model * vec4(i_norm, 0.0)).xyz;
    v2f_color = i_color;
  }
  `

  UNLIT_FS := `#version 300 es
  precision highp float;

  in vec2 v2f_uv;
  in vec3 v2f_norm;
  in vec4 v2f_color;

  uniform vec4 u_color;
  uniform sampler2D u_texture;

  out vec4 o_color;

  void main() {
    vec4 col = texture(u_texture, v2f_uv);

    col *= u_color;

    col *= v2f_color;

    o_color = col;
  }
  `

// Tilemap Materials //////////////////////////////////////////////////////////////////////////////

  TILEMAP_VS := `#version 300 es
  precision highp float;

  layout(location=0) in vec3 i_position;
  layout(location=1) in vec2 i_uv;

  uniform mat4 u_matrix_view_projection; // projection * view
  uniform mat4 u_matrix_model;

  out vec2 v2f_uv;

  void main() {
    gl_Position = (u_matrix_view_projection * u_matrix_model) * vec4(i_position, 1.0);
    v2f_uv = vec2(i_uv.x, 1.0 - i_uv.y);
  }
  `

  TILEMAP_FS := `#version 300 es
  precision highp float;
  precision highp usampler2D;

  in vec2 v2f_uv;

  uniform sampler2D u_tilemap;
  uniform usampler2D u_room_tiles;

  out vec4 o_color;

  #define TILEMAP_WIDTH (768.0/32.0)
  #define TILEMAP_HEIGHT (1280.0/32.0)

  #define ROOM_WIDTH (19.0)
  #define ROOM_HEIGHT (12.0)

  void main() {
    ivec2 tile_index = ivec2(int(ROOM_WIDTH * (floor(ROOM_HEIGHT * v2f_uv.y) + v2f_uv.x)), 0);
    uint tile_id = texelFetch(u_room_tiles, tile_index, 0).x;
    float clip = 0.0;
    if (tile_id != 0U) {
      tile_id -= 1U;
      clip = 1.0;
    }
    vec2 tilemap_pos = vec2(float(tile_id % uint(TILEMAP_WIDTH)), float(tile_id / uint(TILEMAP_WIDTH)));
    vec2 uv = (tilemap_pos + 0.005 + (0.99*fract(vec2(v2f_uv.x * ROOM_WIDTH, v2f_uv.y * ROOM_HEIGHT)))) / vec2(TILEMAP_WIDTH, TILEMAP_HEIGHT);
    uv.y = 1.0 - uv.y;

    // uv = v2f_uv;

    vec4 col = texture(u_tilemap, uv);
/*

    col = vec4(fract(vec2(v2f_uv.x * ROOM_WIDTH, v2f_uv.y * ROOM_HEIGHT)), 0.0, 1.0);
    clip = 1.0;
    vec4 col = texture(u_tilemap, v2f_uv);
    col = vec4(float(uint(tile_id) % 25U) / 25.0, 0, 0, 1);
    clip = 1.0;
*/
    o_color = clip * col;
  }
  `

// Sprite Materials /////////////////////////////////////////////////////////////////////////////////

  SPRITE_VS := `#version 300 es
  precision highp float;

  layout(location=0) in vec3 i_position;
  layout(location=1) in vec2 i_uv;

  uniform mat4 u_matrix_view_projection; // projection * view
  uniform mat4 u_matrix_model;
  uniform vec4 u_sprite_rect;

  out vec2 v2f_uv;

  void main() {
    gl_Position = (u_matrix_view_projection * u_matrix_model) * vec4(i_position, 1.0);
    v2f_uv = u_sprite_rect.xy + (i_uv * u_sprite_rect.zw);
  }
  `

  SPRITE_FS := `#version 300 es
  precision highp float;

  in vec2 v2f_uv;
  in vec3 v2f_norm;
  in vec4 v2f_color;

  uniform vec4 u_color;
  uniform sampler2D u_texture;

  out vec4 o_color;

  void main() {
    vec4 col = texture(u_texture, v2f_uv);

    col *= u_color;

    o_color = col;
  }
  `

// Lit Materials ///////////////////////////////////////////////////////////////////////////////////

  // TODO (hitch) 2023-03-13 Implement lighting?

  LIT_VS := `#version 300 es
  precision highp float;

  layout(location=0) in vec3 i_position;
  layout(location=1) in vec2 i_uv;
  layout(location=2) in vec3 i_norm;

  uniform mat4 u_matrix_projection;
  uniform mat4 u_matrix_view;
  uniform mat4 u_matrix_model;

  out vec2 v2f_uv;
  out vec3 v2f_norm;

  void main() {
    gl_Position = (u_matrix_projection * u_matrix_view * u_matrix_model) * vec4(i_position, 1.0);
    v2f_uv = i_uv;
    v2f_norm = normalize(u_matrix_model * vec4(i_norm, 0.0)).xyz;
  }
  `

  LIT_FS := `#version 300 es
  precision highp float;

  in vec2 v2f_uv;
  in vec3 v2f_norm;

  uniform sampler2D u_texture;

  out vec4 o_color;

  void main() {
    vec4 col = texture(u_texture, v2f_uv);
    col = vec4(1, 0.5, 0.0, 1.0);

    float light = dot(normalize(vec3(2, -5, 1)), v2f_norm);
    col = vec4(light * col.rgb, col.a);

    o_color = col;
  }
  `
