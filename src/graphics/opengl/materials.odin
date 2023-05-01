package opengl

import "project:graphics"

VERT_ATTRIB_POS_LOC :: 0
VERT_ATTRIB_UV_LOC :: 1
VERT_ATTRIB_NORM_LOC :: 2
VERT_ATTRIB_COLOR_LOC :: 3

// TODO (hitch) 2023-03-13 This is not a great way to store and load shaders, I could easily copy paste the wrong shader in draw functions, and it has not runtime enforcement of all Material types...
material_shaders : map[typeid]ShaderProgram

init_materials :: proc() {
  ok : bool
  // TODO (hitch) 2023-03-07 Error Handling...
  material_shaders[graphics.MaterialUnlit], ok = program_from_source(UNLIT_VS, UNLIT_FS)
  if !ok {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }
  material_shaders[graphics.MaterialLit], ok = program_from_source(LIT_VS, LIT_FS)
  if !ok {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }
  material_shaders[graphics.MaterialTilemap], ok = program_from_source(TILEMAP_VS, TILEMAP_FS)
  if !ok {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }
  material_shaders[graphics.MaterialSprite], ok = program_from_source(SPRITE_VS, SPRITE_FS)
  if !ok {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }
  material_shaders[graphics.MaterialEggDoor], ok = program_from_source(SPRITE_VS, EGG_DOOR_FS)
  if !ok {
    // What should we do? Error is reported by loading proc...
    panic("ERR")
  }
}

// Unlit Materials /////////////////////////////////////////////////////////////////////////////////

  UNLIT_VS := `#version 330 core

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

  UNLIT_FS := `#version 330 core

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

  TILEMAP_VS := `#version 330 core

  layout(location=0) in vec3 i_position;
  layout(location=1) in vec2 i_uv;

  uniform mat4 u_matrix_view_projection; // projection * view
  uniform mat4 u_matrix_model;

  out vec2 v2f_uv;

  void main() {
    gl_Position = (u_matrix_view_projection * u_matrix_model) * vec4(i_position, 1.0);
    v2f_uv = vec2(i_uv.x, 1 - i_uv.y);
  }
  `

  TILEMAP_FS := `#version 330 core

  in vec2 v2f_uv;

  uniform sampler2D u_tilemap;
  uniform usamplerBuffer u_room_tiles;

  out vec4 o_color;

  #define TILEMAP_PX_WIDTH (512)
  #define TILEMAP_PX_HEIGHT (512)

  #define TILE_PX_SIZE (16)

  #define ROOM_WIDTH (12)
  #define ROOM_HEIGHT (9)

  #define TILEMAP_TILE_WIDTH (TILEMAP_PX_WIDTH/TILE_PX_SIZE)
  #define TILEMAP_TILE_HEIGHT (TILEMAP_PX_HEIGHT/TILE_PX_SIZE)


  vec2 map(vec2 value, vec2 a_in, vec2 b_in, vec2 a_out, vec2 b_out) {
    return a_out + (b_out - a_out) * (value - a_in) / (b_in - a_in);
  }

  void main() {
    int x_idx = int(ROOM_WIDTH * v2f_uv.x);
    int y_idx = int(ROOM_HEIGHT * v2f_uv.y);
    int tile_index = (ROOM_WIDTH * y_idx) + x_idx;
    uint tile_id = texelFetch(u_room_tiles, tile_index).x;
    float clip = 0;
    if (tile_id != 0U) {
      tile_id -= 1U;
      clip = 1;
    }
    vec2 uv_min = vec2(float(x_idx) / ROOM_WIDTH, float(y_idx) / ROOM_HEIGHT);
    vec2 uv_max = vec2(float(x_idx+1) / ROOM_WIDTH, float(y_idx+1) / ROOM_HEIGHT);
    vec2 tilemap_pos = vec2(float(tile_id % uint(TILEMAP_TILE_WIDTH)), float(tile_id / uint(TILEMAP_TILE_WIDTH)));
    vec2 uv = (tilemap_pos + map(v2f_uv.xy, uv_min, uv_max, vec2(0.1, 0.1)/TILE_PX_SIZE, vec2(TILE_PX_SIZE-0.1, TILE_PX_SIZE-0.1)/TILE_PX_SIZE)) / vec2(TILEMAP_TILE_WIDTH, TILEMAP_TILE_HEIGHT);
    uv.y = 1 - uv.y;

    // Correct
    //*
    vec4 col = texture(u_tilemap, uv);
    // */

    // tile_id:
    /*
    vec4 col = texture(u_tilemap, v2f_uv);
    col = vec4(float(uint(tile_id) % 25U) / 25.0);
    col.w = 1;
    clip = 1;
    // */

    // tile_index:
    /*
    vec4 col = texture(u_tilemap, v2f_uv);
    col = vec4(float(uint(tile_index) % 5U) / 5.0);
    col.w = 1;
    clip = 1;
    // */

    o_color = clip * col;
  }
  `

// Sprite Materials /////////////////////////////////////////////////////////////////////////////////

  SPRITE_VS := `#version 330 core

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

  SPRITE_FS := `#version 330 core

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

  EGG_DOOR_FS := `#version 330 core

  in vec2 v2f_uv;
  in vec3 v2f_norm;
  in vec4 v2f_color;

  uniform int u_egg_count;

  uniform vec4 u_color;
  uniform sampler2D u_texture;

  out vec4 o_color;

  void main() {
    vec4 col = texture(u_texture, v2f_uv);

    if (col.r > 0.99) {
      int required = (int(col.g * 255) + 5) / 10;
      if (u_egg_count > required) {
        col = vec4(0.9725490196078431, 0.6705882352941176, 0.18823529411764706, 1);
      } else {
        col = vec4(0.16470588235294117, 0.30980392156862746, 0.1450980392156863, 1);
      }
    }

    col *= u_color;

    o_color = col;
  }
  `

  // Lit Materials ///////////////////////////////////////////////////////////////////////////////////

// TODO (hitch) 2023-03-13 Implement lighting?
  LIT_VS := `#version 330 core

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

  LIT_FS := `#version 330 core

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
