package windows

import "core:fmt"
import "core:os"
import "core:runtime"
import "core:mem"
import "core:sys/windows"
import "core:strings"

import "vendor:miniaudio"

import "project:platform"


// Global State ////////////////////////////////////////////////////////////////////////////////////

  exe_path : string
  resources_file : os.Handle
  allocator : mem.Allocator
  audio_engine : miniaudio.engine

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
    // exe_path
    {
      w_exe_path : [1024]u16
      w_exe_len := int(windows.GetModuleFileNameW(nil, &w_exe_path[0], len(w_exe_path)))
      if w_exe_len == 0 || w_exe_len == 1024 {
        fmt.eprintln("Could not get current path", w_exe_len)
      }
      err : runtime.Allocator_Error
      exe_path, err = windows.wstring_to_utf8(&w_exe_path[0], w_exe_len, allocator)
      exe_path = exe_path[:strings.last_index_byte(exe_path, '\\')]
      if err != .None {
        fmt.eprintln("Could not get current path", err)
      }
    }

    // resources_file
    {
      resources_path := fmt.aprintf("%v/asset.pak", exe_path)
      defer delete(resources_path)
      err : os.Errno
      resources_file, err = os.open(resources_path)
      if err != os.ERROR_NONE {
        fmt.eprintln("Could not open resources file", err)
      }
    }

    // miniaudio
    {
      if miniaudio.engine_init(nil, &audio_engine) != .SUCCESS {
        fmt.eprintln("failed to init audio engine")
      }
    }
  }

  load_resource :: proc(resource_id : platform.ResourceId) -> (data : []u8, ok : bool) {
    context.allocator = allocator
    location := platform.resource_location(resource_id)
    if location.uncompressed_length > 0 {
      rawdata := make([]u8, location.compressed_length)
      defer delete(rawdata)
      _, err := os.read_at(resources_file, rawdata, location.offset)
      if err == os.ERROR_NONE {
        data = make([]u8, location.uncompressed_length)
        platform.standard_decompression(rawdata, data)
        ok = true
      } else {
        ok = false
      }
    }
    return
  }

  free_resource :: proc(data : []u8) {
    delete(data, allocator)
  }

  Sound :: struct {
    decoder : miniaudio.decoder,
    sound : miniaudio.sound,
  }

  create_sound :: proc(data : []u8, stream := false, looping := false) -> (platform.Sound, bool) {
    sound := new(Sound)
    if miniaudio.decoder_init_memory(&data[0], len(data), nil, &sound.decoder) != .SUCCESS {
      return nil, false
    }
    flags := miniaudio.sound_flags{}
    if stream {
      flags |= miniaudio.sound_flags.STREAM
    }
    if miniaudio.sound_init_from_data_source(&audio_engine, (^miniaudio.data_source)(&sound.decoder), u32(flags), nil, &sound.sound) != .SUCCESS {
      miniaudio.decoder_uninit(&sound.decoder)
      return nil, false
    }
    miniaudio.sound_set_looping(&sound.sound, b32(looping))
    return platform.Sound(sound), true
  }

  free_sound :: proc(sound : platform.Sound) {
    sound := (^Sound)(sound)
    miniaudio.sound_uninit(&sound.sound)
    miniaudio.decoder_uninit(&sound.decoder)
  }

  play_sound :: proc(sound : platform.Sound) {
    sound := (^Sound)(sound)
    if miniaudio.sound_seek_to_pcm_frame(&sound.sound, 0) != .SUCCESS {
      fmt.eprintln("failed to reset sound")
    }
    if miniaudio.sound_start(&sound.sound) != .SUCCESS {
      fmt.eprintln("failed to play sound")
    }
  }

  stop_sound :: proc(sound : platform.Sound) {
    sound := (^Sound)(sound)
    if miniaudio.sound_stop(&sound.sound) != .SUCCESS {
      fmt.eprintln("failed to stop sound")
    }
  }
