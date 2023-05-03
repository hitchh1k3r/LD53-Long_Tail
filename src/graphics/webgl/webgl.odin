package graphics_webgl

import "core:fmt"
import "core:math/linalg"
import "core:slice"

import "project:platform/wasm/webgl"

import "project:graphics"

// Opaque Type Implementations /////////////////////////////////////////////////////////////////////

  Mesh :: struct {
    vao : webgl.VertexArrayObject,
    vbo : webgl.Buffer,
    ibo : webgl.Buffer,
    index_type : graphics.NumberType,
    count : int,
  }

  Texture :: struct {
    texture_id : webgl.Texture,
  }

// Implementation Types ////////////////////////////////////////////////////////////////////////////

  DrawCall :: struct {
    render_order : graphics.RenderOrder,
    sorting : graphics.MaterialSorting,
    shader : ShaderProgram,
    mesh : Mesh,
    // texture : Texture,
    blend_mode : graphics.BlendMode,
    material_flags : graphics.MaterialFlags,
    // color : graphics.Color,
    material : graphics.Material,
    model_matrix : linalg.Matrix4x4f32,
    // draw_flags : graphics.DrawFlags,
    sorting_depth : f32,
  }

// Constants ///////////////////////////////////////////////////////////////////////////////////////

  SIZE_OF_NUMBER_TYPE := [graphics.NumberType]int {
    .I8 = 1,
    .U8 = 1,
    .I16 = 2,
    .U16 = 2,
    .U32 = 4,
    .Float = 4,
  }

  GL_TYPE_OF_NUMBER_TYPE := [graphics.NumberType]webgl.Enum {
    .I8 = webgl.BYTE,
    .U8 = webgl.UNSIGNED_BYTE,
    .I16 = webgl.SHORT,
    .U16 = webgl.UNSIGNED_SHORT,
    .U32 = webgl.UNSIGNED_INT,
    .Float = webgl.FLOAT,
  }

// Global State ////////////////////////////////////////////////////////////////////////////////////

  default_texture : graphics.Texture
  camera_matrix := linalg.MATRIX4F32_IDENTITY
  view_matrix := linalg.MATRIX4F32_IDENTITY
  projection_matrix := linalg.MATRIX4F32_IDENTITY
  view_projection_matrix := linalg.MATRIX4F32_IDENTITY

  draw_queue : [dynamic]DrawCall

// Implementation //////////////////////////////////////////////////////////////////////////////////

  implementation :: graphics.Implementation{

    init = init,

    create_mesh = create_mesh,

    set_target = set_target,

    set_clear_color = set_clear_color,
    /*
    set_clear_depth = set_clear_depth,
    */
    clear_target = clear_target,

    set_projection_matrix = set_projection_matrix,
    set_view_matrix = set_view_matrix,
    set_camera_matrix = set_camera_matrix,

    draw_mesh = draw_mesh,
    queue_draw_mesh = queue_draw_mesh,
    flush_queue = flush_queue,

    create_texture = create_texture,
    create_buffer_texture = create_buffer_texture,

  }

  init :: proc() {
    webgl.CreateCurrentContextById("c", { .disableAlpha, .failIfMajorPerformanceCaveat /*, .desynchronized, .stencil */ })

    init_materials()

    webgl.Enable(webgl.DEPTH_TEST)

    ok : bool
    colors := [][4]u8{ { 255, 255, 255, 255 } }
     if default_texture, ok = create_texture(&colors[0][0], .U8, 1, 1, .RGBA); !ok {
      fmt.eprintln("Could not create default texture...")
    }
  }

  create_mesh :: proc(vert_data : rawptr, vert_count : int, vert_description : graphics.VertDescription, index_data : rawptr, index_count : int, index_num_type : graphics.NumberType) -> (mesh : graphics.Mesh, ok : bool) {
    using result := new(Mesh)
    if index_count > 0 {
      count = index_count
    } else {
      count = vert_count
    }
    index_type = index_num_type

    vao = webgl.CreateVertexArray()
    webgl.BindVertexArray(vao)

    vbo = webgl.CreateBuffer()
    webgl.BindBuffer(webgl.ARRAY_BUFFER, vbo)
    vert_data_size := max(((vert_count-1) * vert_description.pos.stride)   + vert_description.pos.offset   + vert_description.pos.size,
                          ((vert_count-1) * vert_description.uv.stride)    + vert_description.uv.offset    + vert_description.uv.size,
                          ((vert_count-1) * vert_description.norm.stride)  + vert_description.norm.offset  + vert_description.norm.size,
                          ((vert_count-1) * vert_description.color.stride) + vert_description.color.offset + vert_description.color.size)
    webgl.BufferData(webgl.ARRAY_BUFFER, vert_data_size, vert_data, webgl.STATIC_DRAW)

    if vert_description.pos.element_count > 0 {
      webgl.VertexAttribPointer(VERT_ATTRIB_POS_LOC, vert_description.pos.element_count, webgl.FLOAT, false, vert_description.pos.stride, uintptr(vert_description.pos.offset))
      webgl.EnableVertexAttribArray(VERT_ATTRIB_POS_LOC)
    }

    if vert_description.uv.element_count > 0 {
      webgl.VertexAttribPointer(VERT_ATTRIB_UV_LOC, vert_description.uv.element_count, webgl.FLOAT, false, vert_description.uv.stride, uintptr(vert_description.uv.offset))
      webgl.EnableVertexAttribArray(VERT_ATTRIB_UV_LOC)
    }

    if vert_description.norm.element_count > 0 {
      webgl.VertexAttribPointer(VERT_ATTRIB_NORM_LOC, vert_description.norm.element_count, webgl.FLOAT, false, vert_description.norm.stride, uintptr(vert_description.norm.offset))
      webgl.EnableVertexAttribArray(VERT_ATTRIB_NORM_LOC)
    }

    if vert_description.color.element_count > 0 {
      webgl.VertexAttribPointer(VERT_ATTRIB_COLOR_LOC, vert_description.color.element_count, webgl.FLOAT, false, vert_description.color.stride, uintptr(vert_description.color.offset))
      webgl.EnableVertexAttribArray(VERT_ATTRIB_COLOR_LOC)
    }

    if index_count > 0 {
      ibo = webgl.CreateBuffer()
      webgl.BindBuffer(webgl.ELEMENT_ARRAY_BUFFER, ibo)
      webgl.BufferData(webgl.ELEMENT_ARRAY_BUFFER, index_count * SIZE_OF_NUMBER_TYPE[index_num_type], index_data, webgl.STATIC_DRAW)
    }

    webgl.BindVertexArray(0)

    return graphics.Mesh(result), true
  }


  set_target :: proc(frame_buffer : graphics.FrameBuffer) {
  }


  set_clear_color :: proc(color : graphics.Color) {
    webgl.ClearColor(color.r, color.g, color.b, color.a)
  }

  /*
  set_clear_depth :: proc(depth : f64) {
    webgl.ClearDepth(depth)
  }
  */

  clear_target :: proc(flags : graphics.ClearFlags) {
    gl_flags : webgl.Enum
    if .Color in flags {
      gl_flags |= webgl.COLOR_BUFFER_BIT
    }
    if .Depth in flags {
      gl_flags |= webgl.DEPTH_BUFFER_BIT
    }
    webgl.ColorMask(true, true, true, true)
    webgl.DepthMask(true)
    webgl.Clear(gl_flags)
  }

  set_projection_matrix :: proc(mat : linalg.Matrix4x4f32) {
    projection_matrix = mat
    view_projection_matrix = projection_matrix * view_matrix
  }

  set_view_matrix :: proc(mat : linalg.Matrix4x4f32) {
    camera_matrix = linalg.matrix4_inverse(mat)
    view_matrix = mat
    view_projection_matrix = projection_matrix * view_matrix
  }

  set_camera_matrix :: proc(mat : linalg.Matrix4x4f32) {
    camera_matrix = mat
    view_matrix = linalg.matrix4_inverse(mat)
    view_projection_matrix = projection_matrix * view_matrix
  }

  draw_mesh :: proc(mesh : graphics.Mesh, material : graphics.Material, model_matrix : linalg.Matrix4x4f32, draw_flags : graphics.DrawFlags) {
    // TODO (hitch) 2023-03-08 Frustum Culling

    // Material Setting:
    shader : ShaderProgram
    blend_mode : graphics.BlendMode
    material_flags : graphics.MaterialFlags

    switch material in material {
      case graphics.MaterialUnlit:
        shader = material_shaders[graphics.MaterialUnlit]
        blend_mode = material.blend_mode
        material_flags = material.flags
      case graphics.MaterialLit:
        shader = material_shaders[graphics.MaterialLit]
        blend_mode = material.blend_mode
        material_flags = material.flags
      case graphics.MaterialSprite:
        shader = material_shaders[graphics.MaterialSprite]
        blend_mode = material.blend_mode
        material_flags = material.flags
      case graphics.MaterialTilemap:
        shader = material_shaders[graphics.MaterialTilemap]
        blend_mode = material.blend_mode
        material_flags = material.flags
      case graphics.MaterialEggDoor:
        shader = material_shaders[graphics.MaterialEggDoor]
        blend_mode = material.blend_mode
        material_flags = material.flags
    }

    // Setup Shader:
    webgl.UseProgram(shader.program_id)

    if u_matrix_view_projection, ok := shader.uniforms["u_matrix_view_projection"]; ok {
      webgl.UniformMatrix4fv(u_matrix_view_projection, view_projection_matrix)
    }

    if u_matrix_model, ok := shader.uniforms["u_matrix_model"]; ok {
      model_matrix := model_matrix
      webgl.UniformMatrix4fv(u_matrix_model, model_matrix)
    }

    setup_material_state(material, shader, {}, true)

    if .Disable_Color_Write in material_flags {
      webgl.ColorMask(false, false, false, false)
    } else {
      webgl.ColorMask(true, true, true, true)
    }

    if .Disable_Z_Test in material_flags {
      webgl.DepthFunc(webgl.ALWAYS)
    } else {
      webgl.DepthFunc(webgl.LESS)
    }

    if .Disable_Z_Write in material_flags {
      webgl.DepthMask(false)
    } else {
      webgl.DepthMask(true)
    }

    if .Disable_Back_Culling in material_flags {
      if .Enable_Front_Culling in material_flags {
        webgl.Enable(webgl.CULL_FACE)
        webgl.CullFace(webgl.FRONT)
      } else {
        webgl.Disable(webgl.CULL_FACE)
      }
    } else {
      webgl.Enable(webgl.CULL_FACE)
      if .Enable_Front_Culling in material_flags {
        webgl.CullFace(webgl.FRONT_AND_BACK)
      } else {
        webgl.CullFace(webgl.BACK)
      }
    }

    switch blend_mode {
      case .Opaque:
        webgl.Disable(webgl.BLEND)
      case .Alpha_Blend:
        webgl.Enable(webgl.BLEND)
        webgl.BlendFunc(webgl.SRC_ALPHA, webgl.ONE_MINUS_SRC_ALPHA)
      case .Premultiplied_Add:
        webgl.Enable(webgl.BLEND)
        webgl.BlendFunc(webgl.ONE, webgl.ONE)
    }

    // Default Vertex Attributes:
    webgl.VertexAttrib3f(VERT_ATTRIB_POS_LOC, 0, 0, 0)
    webgl.VertexAttrib2f(VERT_ATTRIB_UV_LOC, 0, 0)
    webgl.VertexAttrib3f(VERT_ATTRIB_NORM_LOC, 0, 1, 0)
    webgl.VertexAttrib4f(VERT_ATTRIB_COLOR_LOC, 1, 1, 1, 1)

    // Draw:
    mesh := (^Mesh)(mesh)
    webgl.BindVertexArray(mesh.vao)
    if mesh.ibo > 0 {
      webgl.DrawElements(webgl.TRIANGLES, mesh.count, GL_TYPE_OF_NUMBER_TYPE[mesh.index_type], nil)
    } else {
      webgl.DrawArrays(webgl.TRIANGLES, 0, mesh.count)
    }
    webgl.BindVertexArray(0)
  }

  queue_draw_mesh :: proc(mesh : graphics.Mesh, material : graphics.Material, model_matrix : linalg.Matrix4x4f32, draw_flags : graphics.DrawFlags) {
    // TODO (hitch) 2023-03-08 Frustum Culling

    draw_call : DrawCall
    // opaque_texture : graphics.Texture

    switch material in material {
      case graphics.MaterialUnlit:
        draw_call.render_order = material.render_order
        draw_call.sorting = material.sorting
        draw_call.shader = material_shaders[graphics.MaterialUnlit]
        // opaque_texture = material.texture
        draw_call.blend_mode = material.blend_mode
        draw_call.material_flags = material.flags
        // draw_call.color = material.color
      case graphics.MaterialLit:
        draw_call.render_order = material.render_order
        draw_call.sorting = material.sorting
        draw_call.shader = material_shaders[graphics.MaterialLit]
        // opaque_texture = material.texture
        draw_call.blend_mode = material.blend_mode
        draw_call.material_flags = material.flags
        // draw_call.color = material.color
      case graphics.MaterialSprite:
        draw_call.render_order = material.render_order
        draw_call.sorting = material.sorting
        draw_call.shader = material_shaders[graphics.MaterialSprite]
        draw_call.blend_mode = material.blend_mode
        draw_call.material_flags = material.flags
      case graphics.MaterialEggDoor:
        draw_call.render_order = material.render_order
        draw_call.sorting = material.sorting
        draw_call.shader = material_shaders[graphics.MaterialEggDoor]
        draw_call.blend_mode = material.blend_mode
        draw_call.material_flags = material.flags
      case graphics.MaterialTilemap:
        draw_call.render_order = material.render_order
        draw_call.sorting = material.sorting
        draw_call.shader = material_shaders[graphics.MaterialTilemap]
        draw_call.blend_mode = material.blend_mode
        draw_call.material_flags = material.flags
    }

    // if opaque_texture != nil {
    //   draw_call.texture = ((^Texture)(opaque_texture))^
    // } else {
    //   draw_call.texture = ((^Texture)(default_texture))^
    // }

    draw_call.mesh = ((^Mesh)(mesh))^
    draw_call.material = material
    draw_call.model_matrix = model_matrix
    // draw_call.draw_flags = draw_flags
    if draw_call.sorting != .None {
      model_pos := [3]f32{ model_matrix[3][0], model_matrix[3][1], model_matrix[3][2] }
      cam_pos := [3]f32{ camera_matrix[3][0], camera_matrix[3][1], camera_matrix[3][2] }
      diff := model_pos - cam_pos
      draw_call.sorting_depth = linalg.dot(diff, diff)
    }

    append(&draw_queue, draw_call)
  }

  flush_queue :: proc() {
    if len(draw_queue) == 0 {
      return
    }

    slice.sort_by_cmp(draw_queue[:], proc(l, r : DrawCall) -> slice.Ordering {
      // 0 render_order
      if l.render_order < r.render_order {
        return .Less
      } else if l.render_order > r.render_order {
        return .Greater
      }
      //   if sorting is forced, we sort all draw calls (no batching...), back to front will be batched at the end of this render_order, front to back will be batched at the start
      //    ?? maybe some meshes will sort to the same (or close enough) depth, and we can group them (for instancing, maybe only if instancing, and/or we can have a grouping depth threshold)
      if l.sorting == .Forced_Back_To_Front {
        if r.sorting == .Forced_Back_To_Front {
          if l.sorting_depth > r.sorting_depth {
            return .Less
          } else if l.sorting_depth < r.sorting_depth {
            return .Greater
          }
        } else {
          return .Greater
        }
      }
      if r.sorting == .Forced_Back_To_Front {
        return .Less
      }
      if l.sorting == .Forced_Front_To_Back {
        if r.sorting == .Forced_Front_To_Back {
          if l.sorting_depth > r.sorting_depth {
            return .Greater
          } else if l.sorting_depth < r.sorting_depth {
            return .Less
          }
        } else {
          return .Less
        }
      }
      if r.sorting == .Forced_Front_To_Back {
        return .Greater
      }
      // 1 shader
      if l.shader.program_id < r.shader.program_id {
        return .Less
      } else if l.shader.program_id > r.shader.program_id {
        return .Greater
      }
      // 2 mesh
      if l.mesh.vao < r.mesh.vao {
        return .Less
      } else if l.mesh.vao > r.mesh.vao {
        return .Greater
      }
      // 3 texture (skip if using an instancing shader)
      if result := comp_material_textures(l.material, r.material); result != .Equal {
        return result
      }
      // 4 blend mode
      if l.blend_mode < r.blend_mode {
        return .Less
      } else if l.blend_mode > r.blend_mode {
        return .Greater
      }
      // 5 flags (z write, z test, color write, face culling)
      if l.material_flags < r.material_flags {
        return .Less
      } else if l.material_flags > r.material_flags {
        return .Greater
      }
      // 6 color (skip if using an instancing shader)
      if result := comp_material_color(l.material, r.material); result != .Equal {
        return result
      }
      //   if sorting is batched, we sort all draw calls in this batch
      if l.sorting == .Batch_Back_To_Front {
        if r.sorting == .Batch_Back_To_Front {
          if l.sorting_depth > r.sorting_depth {
            return .Less
          } else if l.sorting_depth < r.sorting_depth {
            return .Greater
          }
        } else {
          return .Greater
        }
      }
      if r.sorting == .Batch_Back_To_Front {
        return .Less
      }
      if l.sorting == .Batch_Front_To_Back {
        if r.sorting == .Batch_Front_To_Back {
          if l.sorting_depth > r.sorting_depth {
            return .Greater
          } else if l.sorting_depth < r.sorting_depth {
            return .Less
          }
        } else {
          return .Less
        }
      }
      if r.sorting == .Batch_Front_To_Back {
        return .Greater
      }

      return .Equal
    })

    last_shader := max(webgl.Program)
    last_material_state : MaterialState
    last_material_flags := ~draw_queue[0].material_flags
    last_blend_mode := graphics.BlendMode(-1)
    last_mesh := max(webgl.VertexArrayObject)

    for draw in draw_queue {
      using draw

      defer last_shader = shader.program_id
      defer last_material_flags = material_flags
      defer last_blend_mode = blend_mode
      defer last_mesh = mesh.vao

      // Setup Shader:
      if last_shader != shader.program_id {
        webgl.UseProgram(shader.program_id)

        if u_matrix_view_projection, ok := shader.uniforms["u_matrix_view_projection"]; ok {
          webgl.UniformMatrix4fv(u_matrix_view_projection, view_projection_matrix)
        }
      }

      if u_matrix_model, ok := shader.uniforms["u_matrix_model"]; ok {
        model_matrix := model_matrix
        webgl.UniformMatrix4fv(u_matrix_model, model_matrix)
      }

      last_material_state = setup_material_state(material, shader, last_material_state)

      changed_material_flags := last_material_flags ~ material_flags
      if changed_material_flags != {} {
        if .Disable_Color_Write in changed_material_flags {
          if .Disable_Color_Write in material_flags {
            webgl.ColorMask(false, false, false, false)
          } else {
            webgl.ColorMask(true, true, true, true)
          }
        }

        if .Disable_Z_Test in changed_material_flags {
          if .Disable_Z_Test in material_flags {
            webgl.DepthFunc(webgl.ALWAYS)
          } else {
            webgl.DepthFunc(webgl.LESS)
          }
        }

        if .Disable_Z_Write in changed_material_flags {
          if .Disable_Z_Write in material_flags {
            webgl.DepthMask(false)
          } else {
            webgl.DepthMask(true)
          }
        }

        if .Disable_Back_Culling in changed_material_flags || .Enable_Front_Culling in changed_material_flags {
          if .Disable_Back_Culling in material_flags {
            if .Enable_Front_Culling in material_flags {
              webgl.Enable(webgl.CULL_FACE)
              webgl.CullFace(webgl.FRONT)
            } else {
              webgl.Disable(webgl.CULL_FACE)
            }
          } else {
            webgl.Enable(webgl.CULL_FACE)
            if .Enable_Front_Culling in material_flags {
              webgl.CullFace(webgl.FRONT_AND_BACK)
            } else {
              webgl.CullFace(webgl.BACK)
            }
          }
        }
      }

      if last_blend_mode != blend_mode {
        switch blend_mode {
          case .Opaque:
            webgl.Disable(webgl.BLEND)
          case .Alpha_Blend:
            webgl.Enable(webgl.BLEND)
            webgl.BlendFunc(webgl.SRC_ALPHA, webgl.ONE_MINUS_SRC_ALPHA)
          case .Premultiplied_Add:
            webgl.Enable(webgl.BLEND)
            webgl.BlendFunc(webgl.ONE, webgl.ONE)
        }
      }

      // Default Vertex Attributes:
      webgl.VertexAttrib3f(VERT_ATTRIB_POS_LOC, 0, 0, 0)
      webgl.VertexAttrib2f(VERT_ATTRIB_UV_LOC, 0, 0)
      webgl.VertexAttrib3f(VERT_ATTRIB_NORM_LOC, 0, 1, 0)
      webgl.VertexAttrib4f(VERT_ATTRIB_COLOR_LOC, 1, 1, 1, 1)

      // Draw:
      if last_mesh != mesh.vao {
        webgl.BindVertexArray(mesh.vao)
      }
      if mesh.ibo > 0 {
        webgl.DrawElements(webgl.TRIANGLES, mesh.count, GL_TYPE_OF_NUMBER_TYPE[mesh.index_type], nil)
      } else {
        webgl.DrawArrays(webgl.TRIANGLES, 0, mesh.count)
      }
    }

    webgl.BindVertexArray(0)
    clear(&draw_queue)
  }

  create_texture :: proc(data : rawptr, data_type : graphics.NumberType, width, height : i32, pixel_format : graphics.PixelFormat) -> (texture : graphics.Texture, ok : bool) {
    using gl_texture := new(Texture)

    // TODO (hitch) 2023-03-24 If GL_TYPE_OF_NUMBER_TYPE[data_type] is not Unsigned_Int, javascript will expect a different array type!

    texture_id = webgl.CreateTexture()
    webgl.BindTexture(webgl.TEXTURE_2D, texture_id)
    switch pixel_format {
      case .RGB:
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.RGB, width, height, 0, webgl.RGB, GL_TYPE_OF_NUMBER_TYPE[data_type], 3 * int(width * height) * graphics.SIZE_OF_NUMBER_TYPE[data_type], data)
      case .RGBA:
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.RGBA, width, height, 0, webgl.RGBA, GL_TYPE_OF_NUMBER_TYPE[data_type], 4 * int(width * height) * graphics.SIZE_OF_NUMBER_TYPE[data_type], data)
    }

    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_S, i32(webgl.REPEAT))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_T, i32(webgl.REPEAT))

    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MIN_FILTER, i32(webgl.NEAREST))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MAG_FILTER, i32(webgl.NEAREST))

    webgl.BindTexture(webgl.TEXTURE_2D, 0)

    return graphics.Texture(gl_texture), true
  }

  create_buffer_texture :: proc(data : rawptr, data_size : int, buffer_format : graphics.BufferFormat) -> (texture : graphics.Texture, ok : bool) {
    using gl_texture := new(Texture)

    // TODO (hitch) 2023-03-24 If GL_TYPE_OF_NUMBER_TYPE[data_type] is not Unsigned_Int, javascript will expect a different array type!

    texture_id = webgl.CreateTexture()
    webgl.BindTexture(webgl.TEXTURE_2D, texture_id)

    switch buffer_format {
      case .FLOAT_1_32:
        width := i32(data_size / (1 * graphics.SIZE_OF_NUMBER_TYPE[.Float]))
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.R32F, width, 1, 0, webgl.RED, GL_TYPE_OF_NUMBER_TYPE[.Float], data_size, data)
      case .UINT_1_8:
        width := i32(data_size / (1 * graphics.SIZE_OF_NUMBER_TYPE[.U8]))
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.R8UI, width, 1, 0, webgl.RED_INTEGER, GL_TYPE_OF_NUMBER_TYPE[.U8], data_size, data)
      case .UINT_1_32:
        width := i32(data_size / (1 * graphics.SIZE_OF_NUMBER_TYPE[.U32]))
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.R32UI, width, 1, 0, webgl.RED_INTEGER, GL_TYPE_OF_NUMBER_TYPE[.U32], data_size, data)
      case .UINT_3_8:
        width := i32(data_size / (3 * graphics.SIZE_OF_NUMBER_TYPE[.U8]))
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.RGB8UI, width, 1, 0, webgl.RGB8UI, GL_TYPE_OF_NUMBER_TYPE[.U8], data_size, data)
      case .UINT_4_8:
        width := i32(data_size / (4 * graphics.SIZE_OF_NUMBER_TYPE[.U8]))
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.RGBA8UI, width, 1, 0, webgl.RGBA_INTEGER, GL_TYPE_OF_NUMBER_TYPE[.U8], data_size, data)
      case .UINT_4_32:
        width := i32(data_size / (4 * graphics.SIZE_OF_NUMBER_TYPE[.U32]))
        webgl.TexImage2D(webgl.TEXTURE_2D, 0, webgl.RGBA32UI, width, 1, 0, webgl.RGBA_INTEGER, GL_TYPE_OF_NUMBER_TYPE[.U32], data_size, data)
    }

    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_S, i32(webgl.CLAMP_TO_EDGE))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_T, i32(webgl.CLAMP_TO_EDGE))

    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MIN_FILTER, i32(webgl.NEAREST))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MAG_FILTER, i32(webgl.NEAREST))

    webgl.BindTexture(webgl.TEXTURE_2D, 0)

    return graphics.Texture(gl_texture), true
  }

// Internal ////////////////////////////////////////////////////////////////////////////////////////

  SPRITE_INSET :: 0.1 / 512.0

  MAX_TEXTURES :: 16

  TextureBind :: struct {
    uniform_loc : i32,
    id : webgl.Texture,
    mode : enum { Texture, Buffer_Texture },
  }

  MaterialState :: struct {
    texture_count : u32,
    texture_binds : [MAX_TEXTURES]TextureBind,
    color : graphics.Color,
    rect : graphics.Rect, // TODO (hitch) 2023-03-13 This is not the best way to add new state probably... it's also not being sorted on!
    shader : webgl.Program,
    egg_count : int,
  }

  setup_material_state :: proc(material : graphics.Material, shader : ShaderProgram, last_state : MaterialState, force_state_update := false) -> MaterialState {
    @static new_state : MaterialState
    new_state = {}
    new_state.shader = shader.program_id

    force_state_update := force_state_update
    if !force_state_update && shader.program_id != last_state.shader {
      force_state_update = true
    }

    @static _last_state : MaterialState
    _last_state = last_state
    @static _force_state_update : bool
    _force_state_update = force_state_update

    bind_buffer_texture :: proc(buffer_texture : graphics.Texture, uniform_loc : i32) {
      buffer_texture := buffer_texture
      if buffer_texture == nil {
        buffer_texture = default_texture
      }
      {
        buffer_texture := (^Texture)(buffer_texture)
        if _force_state_update || _last_state.texture_count < new_state.texture_count || _last_state.texture_binds[new_state.texture_count] != { uniform_loc, buffer_texture.texture_id, .Buffer_Texture } {
          webgl.ActiveTexture(webgl.TEXTURE0 + webgl.Enum(new_state.texture_count))
          webgl.BindTexture(webgl.TEXTURE_2D, buffer_texture.texture_id)
          webgl.Uniform1i(uniform_loc, i32(new_state.texture_count))
        }

        new_state.texture_binds[new_state.texture_count] = { uniform_loc, buffer_texture.texture_id, .Buffer_Texture }
        new_state.texture_count += 1
      }
    }

    bind_texture :: proc(texture : graphics.Texture, uniform_loc : i32) {
      texture := texture
      if texture == nil {
        texture = default_texture
      }
      {
        texture := (^Texture)(texture)
        if _force_state_update || _last_state.texture_count < new_state.texture_count || _last_state.texture_binds[new_state.texture_count] != { uniform_loc, texture.texture_id, .Texture } {
          webgl.ActiveTexture(webgl.TEXTURE0 + webgl.Enum(new_state.texture_count))
          webgl.BindTexture(webgl.TEXTURE_2D, texture.texture_id)
          webgl.Uniform1i(uniform_loc, i32(new_state.texture_count))
        }

        new_state.texture_binds[new_state.texture_count] = { uniform_loc, texture.texture_id, .Texture }
        new_state.texture_count += 1
      }
    }

    V4 :: [4]f32

    switch material in material {
      case graphics.MaterialUnlit:
        bind_texture(material.texture, shader.uniforms["u_texture"])

        if _force_state_update || last_state.color != material.color {
          color := material.color
          webgl.Uniform4fv(shader.uniforms["u_color"], V4(color))
        }
        new_state.color = material.color

      case graphics.MaterialLit:
        bind_texture(material.texture, shader.uniforms["u_texture"])

        if _force_state_update || last_state.color != material.color {
          color := material.color
          webgl.Uniform4fv(shader.uniforms["u_color"], V4(color))
        }
        new_state.color = material.color

      case graphics.MaterialSprite:
        bind_texture(material.spritesheet, shader.uniforms["u_texture"])

        if _force_state_update || last_state.color != material.color {
          color := material.color
          webgl.Uniform4fv(shader.uniforms["u_color"], V4(color))
        }
        new_state.color = material.color

        if _force_state_update || last_state.rect != material.rect {
          rect := V4{ material.rect.x+SPRITE_INSET, material.rect.y+SPRITE_INSET, material.rect.width-(2*SPRITE_INSET), material.rect.height-(2*SPRITE_INSET) }
          webgl.Uniform4fv(shader.uniforms["u_sprite_rect"], rect)
        }
        new_state.rect = material.rect

      case graphics.MaterialEggDoor:
        bind_texture(material.spritesheet, shader.uniforms["u_texture"])

        if _force_state_update || last_state.color != material.color {
          color := material.color
          webgl.Uniform4fv(shader.uniforms["u_color"], ([4]f32)(color))
        }
        new_state.color = material.color

        if _force_state_update || last_state.rect != material.rect {
          rect := V4{ material.rect.x+SPRITE_INSET, material.rect.y+SPRITE_INSET, material.rect.width-(2*SPRITE_INSET), material.rect.height-(2*SPRITE_INSET) }
          webgl.Uniform4fv(shader.uniforms["u_sprite_rect"], rect)
        }
        new_state.rect = material.rect

        if _force_state_update || last_state.egg_count != material.egg_count {
          webgl.Uniform1i(shader.uniforms["u_egg_count"], i32(material.egg_count))
        }
        new_state.egg_count = material.egg_count

      case graphics.MaterialTilemap:
        bind_texture(material.tilemap, shader.uniforms["u_tilemap"])
        bind_buffer_texture(material.tiles, shader.uniforms["u_room_tiles"])
    }

    return new_state
  }

  comp_material_textures :: proc(l, r : graphics.Material) -> slice.Ordering {
    l_textures, r_textures : [MAX_TEXTURES]u32
    l_count, r_count : int

    get_id :: proc(texture : graphics.Texture) -> u32 {
      if texture == nil {
        return u32((^Texture)(default_texture).texture_id)
      }
      return u32((^Texture)(texture).texture_id)
    }

    switch material in l {
      case graphics.MaterialUnlit:
        l_count = 1
        l_textures[0] = get_id(material.texture)
      case graphics.MaterialLit:
        l_count = 1
        l_textures[0] = get_id(material.texture)
      case graphics.MaterialSprite:
        l_count = 1
        l_textures[0] = get_id(material.spritesheet)
      case graphics.MaterialEggDoor:
        l_count = 1
        l_textures[0] = get_id(material.spritesheet)
      case graphics.MaterialTilemap:
        l_count = 2
        l_textures[0] = get_id(material.tilemap)
        l_textures[1] = get_id(material.tiles)
    }
    switch material in r {
      case graphics.MaterialUnlit:
        r_count = 1
        r_textures[0] = get_id(material.texture)
      case graphics.MaterialLit:
        r_count = 1
        r_textures[0] = get_id(material.texture)
      case graphics.MaterialSprite:
        r_count = 1
        r_textures[0] = get_id(material.spritesheet)
      case graphics.MaterialEggDoor:
        r_count = 1
        r_textures[0] = get_id(material.spritesheet)
      case graphics.MaterialTilemap:
        r_count = 2
        r_textures[0] = get_id(material.tilemap)
        r_textures[1] = get_id(material.tiles)
    }

    if l_count < r_count {
      return .Less
    } else if l_count > r_count {
      return .Greater
    }
    for i in 0..<l_count {
      if l_textures[i] < r_textures[i] {
        return .Less
      } else if l_textures[i] > r_textures[i] {
        return .Greater
      }
    }
    return .Equal
  }

  comp_material_color :: proc(l, r : graphics.Material) -> slice.Ordering {
    l_color, r_color : graphics.Color
    switch material in l {
      case graphics.MaterialUnlit:
        l_color = material.color
      case graphics.MaterialLit:
        l_color = material.color
      case graphics.MaterialSprite:
        l_color = material.color
      case graphics.MaterialEggDoor:
        l_color = material.color
      case graphics.MaterialTilemap:
        l_color = { 1.0, 1.0, 1.0, 1.0 }
    }
    switch material in r {
      case graphics.MaterialUnlit:
        r_color = material.color
      case graphics.MaterialLit:
        r_color = material.color
      case graphics.MaterialSprite:
        r_color = material.color
      case graphics.MaterialEggDoor:
        r_color = material.color
      case graphics.MaterialTilemap:
        r_color = { 1.0, 1.0, 1.0, 1.0 }
    }

    if l_color.r < r_color.r {
      return .Less
    } else if l_color.r > r_color.r {
      return .Greater
    }
    if l_color.g < r_color.g {
      return .Less
    } else if l_color.g > r_color.g {
      return .Greater
    }
    if l_color.b < r_color.b {
      return .Less
    } else if l_color.b > r_color.b {
      return .Greater
    }
    if l_color.a < r_color.a {
      return .Less
    } else if l_color.a > r_color.a {
      return .Greater
    }
    return .Equal
  }
