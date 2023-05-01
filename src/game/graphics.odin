package game

import "core:fmt"
import "core:mem"

import "project:graphics"
import "project:platform"

meshes : struct {
  quad : graphics.Mesh,
}

@(private="file")
texture_cache : map[platform.ResourceImage]graphics.Texture

load_default_graphics :: proc() {
  ok : bool
  if meshes.quad, ok = graphics.create_mesh_verts([]graphics.Vertex_pos3_uv2{
    { pos = { -0.5, -0.5, 0 }, uv = { 0, 0 } },
    { pos = {  0.5, -0.5, 0 }, uv = { 1, 0 } },
    { pos = {  0.5,  0.5, 0 }, uv = { 1, 1 } },

    { pos = {  0.5,  0.5, 0 }, uv = { 1, 1 } },
    { pos = { -0.5,  0.5, 0 }, uv = { 0, 1 } },
    { pos = { -0.5, -0.5, 0 }, uv = { 0, 0 } },
  }); !ok {
    fmt.eprintln("Could not create quad_mesh")
  }
}

get_texture :: proc(uri : platform.ResourceImage) -> graphics.Texture {
  if texture, ok := texture_cache[uri]; ok {
    return texture
  }

  if file_data, ok := platform.load_resource(uri); ok {
    defer platform.free_resource(file_data)
    read_file := file_data

    width, height : i32
    channels : i8
    mem.copy(&channels, &file_data[0], size_of(i8))
    read_file = read_file[size_of(i8):]
    mem.copy(&width, &read_file[0], size_of(i32))
    read_file = read_file[size_of(i32):]
    mem.copy(&height, &read_file[0], size_of(i32))
    read_file = read_file[size_of(i32):]

    if channels == 3 {
      if texture, ok := graphics.create_texture_raw(read_file[:], .U8, width, height, .RGB); ok {
        texture_cache[uri] = texture
        return texture
      } else {
        fmt.eprintf("Failed to create RGB texture '%v'\n", uri)
        return nil
      }
    } else if channels == 4 {
      if texture, ok := graphics.create_texture_raw(read_file[:], .U8, width, height, .RGBA); ok {
        texture_cache[uri] = texture
        return texture
      } else {
        fmt.eprintf("Failed to create RGBA texture '%v'\n", uri)
        return nil
      }
    } else {
      fmt.eprintf("Failed to create texture '%v', only RGB and RGBA are currently supported\n", uri)
      return nil
    }
  }
  fmt.eprintf("Failed to create texture '%v', could not find or read image\n", uri)
  return nil
}
