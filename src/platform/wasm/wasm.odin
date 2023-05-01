package wasm

import "core:fmt"
import "core:mem"

import "project:platform"

// Global State ////////////////////////////////////////////////////////////////////////////////////

  allocator : mem.Allocator

// Assets //////////////////////////////////////////////////////////////////////////////////////////

  @(private) ASSET_DATA := #load("../../../artifacts/resources/asset.pak")

// Implementation //////////////////////////////////////////////////////////////////////////////////

  implementation :: platform.Implementation{

    init = init,

    load_resource = load_resource,

    free_resource = free_resource,

  }

  init :: proc() {
    allocator = context.allocator
  }

  load_resource :: proc(resource_id : platform.ResourceId) -> (data : []u8, ok : bool) {
    context.allocator = allocator
    location := platform.resource_location(resource_id)
    if location.uncompressed_length > 0 {
      rawdata := ASSET_DATA[location.offset:location.offset+location.compressed_length]
      data = make([]u8, location.uncompressed_length)
      platform.standard_decompression(rawdata, data)
      ok = true
    }
    return
  }

  free_resource :: proc(data : []u8) {
    delete(data, allocator)
  }
