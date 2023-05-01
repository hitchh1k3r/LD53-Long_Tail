package graphics

import "core:math/linalg"
import "core:reflect"

// Basic Types /////////////////////////////////////////////////////////////////////////////////////

  Color :: distinct [4]f32

// Opaque Types ////////////////////////////////////////////////////////////////////////////////////

  Mesh :: distinct rawptr
  Texture :: distinct rawptr
  FrameBuffer :: distinct rawptr

// Enumerations ////////////////////////////////////////////////////////////////////////////////////

  BlendMode :: enum {
    Opaque,
    Alpha_Blend,
    Premultiplied_Add,
  }

  ClearFlag :: enum { Color, Depth }
  ClearFlags :: bit_set[ClearFlag]

  DrawFlag :: enum {
    Disable_Frustum_Culling,
  }
  DrawFlags :: bit_set[DrawFlag]

  RenderOrder :: distinct i32
  RENDER_ORDER_PRE_OPAQUE ::  RenderOrder(- 500)
  RENDER_ORDER_OPAQUE ::      RenderOrder(    0)
  RENDER_ORDER_SKYBOX ::      RenderOrder(  500)
  RENDER_ORDER_ALPHA_TEST ::  RenderOrder( 1000)
  RENDER_ORDER_ALPHA_BLEND :: RenderOrder( 1500)
  RENDER_ORDER_UI ::          RenderOrder( 2000)

  MaterialSorting :: enum {
    None,
    Forced_Back_To_Front,
    Forced_Front_To_Back,
    Batch_Back_To_Front,
    Batch_Front_To_Back,
  }

  MaterialFlag :: enum {
    Disable_Color_Write,
    Disable_Z_Test,
    Disable_Z_Write,
    Disable_Back_Culling,
    Enable_Front_Culling,
  }
  MaterialFlags :: bit_set[MaterialFlag]

  NumberType :: enum {
    I8,
    U8,
    I16,
    U16,
    U32,
    Float,
  }

  SIZE_OF_NUMBER_TYPE := [NumberType]int {
    .I8 = 1,
    .U8 = 1,
    .I16 = 2,
    .U16 = 2,
    .U32 = 4,
    .Float = 4,
  }

  PixelFormat :: enum {
    RGB,
    RGBA,
  }

  BufferFormat :: enum {
    FLOAT_1_32,
    UINT_1_8,
    UINT_1_32,
    UINT_3_8,
    UINT_4_8,
    UINT_4_32,
  }

// Materials ///////////////////////////////////////////////////////////////////////////////////////

  Material :: union {
    MaterialUnlit,
    MaterialLit,
    MaterialTilemap,
    MaterialSprite,
    MaterialEggDoor,
  }

  MaterialUnlit :: struct {
    texture : Texture,
    blend_mode : BlendMode,
    color : Color,
    render_order : RenderOrder,
    sorting : MaterialSorting,
    flags : MaterialFlags,
    alpha_clip : f32,
  }

  MaterialLit :: struct {
    texture : Texture,
    blend_mode : BlendMode,
    color : Color,
    render_order : RenderOrder,
    sorting : MaterialSorting,
    flags : MaterialFlags,
    alpha_clip : f32,
  }

  MaterialTilemap :: struct {
    tilemap : Texture,
    tiles : Texture,
    blend_mode : BlendMode,
    render_order : RenderOrder,
    sorting : MaterialSorting,
    flags : MaterialFlags,
    alpha_clip : f32,
  }

  MaterialSprite :: struct {
    spritesheet : Texture,
    rect : Rect,
    blend_mode : BlendMode,
    color : Color,
    render_order : RenderOrder,
    sorting : MaterialSorting,
    flags : MaterialFlags,
    alpha_clip : f32,
  }

  MaterialEggDoor:: struct {
    spritesheet : Texture,
    rect : Rect,
    egg_count : int,
    blend_mode : BlendMode,
    color : Color,
    render_order : RenderOrder,
    sorting : MaterialSorting,
    flags : MaterialFlags,
    alpha_clip : f32,
  }

// Verticies ///////////////////////////////////////////////////////////////////////////////////////

  Vertex_pos3 ::                  struct { pos : [3]f32                                             }
  Vertex_pos4 ::                  struct { pos : [4]f32                                             }
  Vertex_pos3_uv2 ::              struct { pos : [3]f32, uv : [2]f32                                }
  Vertex_pos4_uv2 ::              struct { pos : [4]f32, uv : [2]f32                                }
  Vertex_pos3_norm3 ::            struct { pos : [3]f32,              norm : [3]f32                 }
  Vertex_pos4_norm3 ::            struct { pos : [4]f32,              norm : [3]f32                 }
  Vertex_pos3_uv2_norm3 ::        struct { pos : [3]f32, uv : [2]f32, norm : [3]f32                 }
  Vertex_pos4_uv2_norm3 ::        struct { pos : [4]f32, uv : [2]f32, norm : [3]f32                 }
  Vertex_pos3_color3 ::           struct { pos : [3]f32,                             color : [3]f32 }
  Vertex_pos4_color3 ::           struct { pos : [4]f32,                             color : [3]f32 }
  Vertex_pos3_uv2_color3 ::       struct { pos : [3]f32, uv : [2]f32,                color : [3]f32 }
  Vertex_pos4_uv2_color3 ::       struct { pos : [4]f32, uv : [2]f32,                color : [3]f32 }
  Vertex_pos3_norm3_color3 ::     struct { pos : [3]f32,              norm : [3]f32, color : [3]f32 }
  Vertex_pos4_norm3_color3 ::     struct { pos : [4]f32,              norm : [3]f32, color : [3]f32 }
  Vertex_pos3_uv2_norm3_color3 :: struct { pos : [3]f32, uv : [2]f32, norm : [3]f32, color : [3]f32 }
  Vertex_pos4_uv2_norm3_color3 :: struct { pos : [4]f32, uv : [2]f32, norm : [3]f32, color : [3]f32 }
  Vertex_pos3_color4 ::           struct { pos : [3]f32,                             color : [4]f32 }
  Vertex_pos4_color4 ::           struct { pos : [4]f32,                             color : [4]f32 }
  Vertex_pos3_uv2_color4 ::       struct { pos : [3]f32, uv : [2]f32,                color : [4]f32 }
  Vertex_pos4_uv2_color4 ::       struct { pos : [4]f32, uv : [2]f32,                color : [4]f32 }
  Vertex_pos3_norm3_color4 ::     struct { pos : [3]f32,              norm : [3]f32, color : [4]f32 }
  Vertex_pos4_norm3_color4 ::     struct { pos : [4]f32,              norm : [3]f32, color : [4]f32 }
  Vertex_pos3_uv2_norm3_color4 :: struct { pos : [3]f32, uv : [2]f32, norm : [3]f32, color : [4]f32 }
  Vertex_pos4_uv2_norm3_color4 :: struct { pos : [4]f32, uv : [2]f32, norm : [3]f32, color : [4]f32 }

  get_vertex_descriptor :: proc($vertex_type : typeid) -> (desc : VertDescription) {
    pos := reflect.struct_field_by_name(vertex_type, "pos")
    if pos.name != "" {
      desc.pos = {
        size = pos.type.size,
        offset = int(pos.offset),
        stride = size_of(vertex_type),
        element_count = pos.type.variant.(reflect.Type_Info_Array).count,
      }
    }
    uv := reflect.struct_field_by_name(vertex_type, "uv")
    if uv.name != "" {
      desc.uv = {
        size = uv.type.size,
        offset = int(uv.offset),
        stride = size_of(vertex_type),
        element_count = uv.type.variant.(reflect.Type_Info_Array).count,
      }
    }
    norm := reflect.struct_field_by_name(vertex_type, "norm")
    if norm.name != "" {
      desc.norm = {
        size = norm.type.size,
        offset = int(norm.offset),
        stride = size_of(vertex_type),
        element_count = norm.type.variant.(reflect.Type_Info_Array).count,
      }
    }
    color := reflect.struct_field_by_name(vertex_type, "color")
    if color.name != "" {
      desc.color = {
        size = color.type.size,
        offset = int(color.offset),
        stride = size_of(vertex_type),
        element_count = color.type.variant.(reflect.Type_Info_Array).count,
      }
    }
    return
  }

  VertDescription :: struct {
    pos : VertElementDescription,
    uv : VertElementDescription,
    norm : VertElementDescription,
    color : VertElementDescription,
  }

  VertElementDescription :: struct {
    size : int,
    offset : int,
    stride : int,
    element_count : int,
  }

// Other Types /////////////////////////////////////////////////////////////////////////////////////

  Rect :: struct {
    x, y : f32,
    width, height : f32,
  }

// Implementation Interface ////////////////////////////////////////////////////////////////////////

  Implementation :: struct {

    init : proc(),

    create_mesh : proc(vert_data : rawptr, vert_count : int, vert_description : VertDescription, index_data : rawptr, index_count : int, index_type : NumberType) -> (mesh : Mesh, ok : bool),

    set_target : proc(frame_buffer : FrameBuffer),

    set_clear_color : proc(color : Color),
    clear_target : proc(flags : ClearFlags),

    set_projection_matrix : proc(mat : linalg.Matrix4x4f32),
    set_view_matrix : proc(mat : linalg.Matrix4x4f32),
    set_camera_matrix : proc(mat : linalg.Matrix4x4f32),

    draw_mesh : proc(mesh : Mesh, material : Material, model_matrix : linalg.Matrix4x4f32, draw_flags : DrawFlags),
    queue_draw_mesh : proc(mesh : Mesh, material : Material, model_matrix : linalg.Matrix4x4f32, draw_flags : DrawFlags),
    flush_queue : proc(),

    create_texture : proc(data : rawptr, data_type : NumberType, width, height : i32, pixel_format : PixelFormat) -> (texture : Texture, ok : bool),
    create_buffer_texture : proc(data : rawptr, data_size : int, buffer_format : BufferFormat) -> (texture : Texture, ok : bool),

  }

  implementation : Implementation

  init :: proc() {
    implementation.init()
  }

  create_mesh :: proc{ create_mesh_verts, create_mesh_raw }

  create_mesh_verts :: proc(verts : []$VertType, indicies : []u32 = {}) -> (mesh : Mesh, ok : bool) {
    return implementation.create_mesh(raw_data(verts), len(verts), get_vertex_descriptor(VertType), raw_data(indicies), len(indicies), .U32)
  }

  create_mesh_raw :: proc(vert_data : rawptr, vert_count : int, vert_description : VertDescription, index_data : rawptr, index_count : int, index_type : NumberType) -> (mesh : Mesh, ok : bool) {
    return implementation.create_mesh(vert_data, vert_count, vert_description, index_data, index_count, index_type)
  }

  set_target :: proc(frame_buffer : FrameBuffer) {
    implementation.set_target(frame_buffer)
  }

  set_clear_color :: proc(color : Color) {
    implementation.set_clear_color(color)
  }

  clear_target :: proc(flags : ClearFlags) {
    implementation.clear_target(flags)
  }


  set_projection_matrix :: proc(mat : linalg.Matrix4x4f32) {
    implementation.set_projection_matrix(mat)
  }

  set_view_matrix :: proc(mat : linalg.Matrix4x4f32) {
    implementation.set_view_matrix(mat)
  }

  set_camera_matrix :: proc(mat : linalg.Matrix4x4f32) {
    implementation.set_camera_matrix(mat)
  }

  draw_mesh :: proc(mesh : Mesh, material : Material, model_matrix : linalg.Matrix4x4f32, draw_flags := DrawFlags{}) {
    implementation.draw_mesh(mesh, material, model_matrix, draw_flags)
  }

  queue_draw_mesh :: proc(mesh : Mesh, material : Material, model_matrix : linalg.Matrix4x4f32, draw_flags := DrawFlags{}) {
    implementation.queue_draw_mesh(mesh, material, model_matrix, draw_flags)
  }

  flush_queue :: proc() {
    implementation.flush_queue()
  }

  create_texture :: proc{ create_texture_colors, create_texture_raw }

  create_texture_colors :: proc(pixels : []Color, #any_int width, height : i32) -> (texture : Texture, ok : bool) {
    return implementation.create_texture(&pixels[0][0], .Float, width, height, .RGBA)
  }

  create_texture_raw :: proc(data : []u8, data_type : NumberType, #any_int width, height : i32, format : PixelFormat) -> (texture : Texture, ok : bool) {
    return implementation.create_texture(&data[0], data_type, width, height, format)
  }

  create_buffer_texture :: proc(data : []u8, buffer_format : BufferFormat) -> (texture : Texture, ok : bool) {
    return implementation.create_buffer_texture(&data[0], len(data), buffer_format)
  }