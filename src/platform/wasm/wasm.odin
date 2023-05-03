package wasm

import "core:fmt"
import "core:mem"

import "project:platform"

foreign import "audio"

// Global State ////////////////////////////////////////////////////////////////////////////////////

  allocator : mem.Allocator

// Assets //////////////////////////////////////////////////////////////////////////////////////////

  @(private) ASSET_DATA := #load("../../../artifacts/resources/asset.pak")

// Implementation //////////////////////////////////////////////////////////////////////////////////

  implementation :: platform.Implementation{

    init = init,

    load_resource = load_resource,
    free_resource = free_resource,

    create_sound = create_sound,
    free_sound = free_sound,
    play_sound = play_sound,
    stop_sound = stop_sound,

  }

  init :: proc() {
    allocator = context.allocator

    foreign audio {
      @(link_name="init_audio")
      _init_audio :: proc "c" () ---
    }
    _init_audio()
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

  create_sound :: proc(data : []u8, stream := false, looping := false) -> (platform.Sound, bool) {
    foreign audio {
      @(link_name="make_sound")
      _make_sound :: proc "c" (data : []u8, looping : bool) -> int ---
    }
    sound_id := new(int)
    sound_id^ = _make_sound(data, looping)
    return platform.Sound(sound_id), true
  }

  free_sound :: proc(sound : platform.Sound) {
    foreign audio {
      @(link_name="free_sound")
      _free_sound :: proc "c" (sound : int) ---
    }
    _free_sound((^int)(sound)^)
  }

  play_sound :: proc(sound : platform.Sound) {
    foreign audio {
      @(link_name="play_sound")
      _play_sound :: proc "c" (sound : int) ---
    }
    _play_sound((^int)(sound)^)
  }

  stop_sound :: proc(sound : platform.Sound) {
    foreign audio {
      @(link_name="stop_sound")
      _stop_sound :: proc "c" (sound : int) ---
    }
    _stop_sound((^int)(sound)^)
  }
