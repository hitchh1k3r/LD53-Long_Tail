package platform

import "core:mem"

// Implementation Interface ////////////////////////////////////////////////////////////////////////

  Sound :: distinct rawptr

  Implementation :: struct {

    init : proc(),

    load_resource : proc(resource_id : ResourceId) -> (data : []u8, ok : bool),
    free_resource : proc(data : []u8),

    create_sound : proc(data : []u8, stream : bool, looping : bool) -> (Sound, bool),
    free_sound : proc(sound : Sound),
    play_sound : proc(sound : Sound),
    stop_sound : proc(sound : Sound),

  }

  implementation : Implementation

  init :: proc() {
    implementation.init()
  }

  load_resource :: proc(resource_id : ResourceId) -> (data : []u8, ok : bool) {
    return implementation.load_resource(resource_id)
  }

  free_resource :: proc(data : []u8) {
    implementation.free_resource(data)
  }

  create_sound :: proc(data : []u8, stream := false, looping := false) -> (Sound, bool) {
    return implementation.create_sound(data, stream, looping)
  }

  free_sound :: proc(sound : Sound) {
    implementation.free_sound(sound)
  }

  play_sound :: proc(sound : Sound) {
    implementation.play_sound(sound)
  }

  stop_sound :: proc(sound : Sound) {
    implementation.stop_sound(sound)
  }

  standard_decompression :: proc(input : []u8, output : []u8) {
    BACKREF_LENGTH_FLAG :: 0b10000000_00000000

    MIN_BACKREF_DISTANCE :: int(1)
    MAX_BACKREF_DISTANCE :: int(max(u16)) + MIN_BACKREF_DISTANCE
    MIN_BACKREF_LENGTH :: int(7)
    MAX_BACKREF_LENGTH :: int(max(u16) >> 1) + MIN_BACKREF_LENGTH

    MIN_LITERAL_LENGTH :: int(1)
    MAX_LITERAL_LENGTH :: int(max(u16) >> 1) + MIN_LITERAL_LENGTH

    read_type :: proc(input : []u8, idx : ^int, $READ_TYPE : typeid, $OUT_TYPE : typeid) -> OUT_TYPE {
      temp : READ_TYPE
      mem.copy(&temp, &input[idx^], size_of(READ_TYPE))
      idx^ += size_of(READ_TYPE)
      return OUT_TYPE(temp)
    }

    write_idx : int
    for read_idx := 0; read_idx < len(input); {
      length := read_type(input, &read_idx, u16le, u16)
      if length & BACKREF_LENGTH_FLAG == BACKREF_LENGTH_FLAG {
        length := int(BACKREF_LENGTH_FLAG ~ length) + MIN_BACKREF_LENGTH
        offset := int(read_type(input, &read_idx, u16le, u16)) + MIN_BACKREF_DISTANCE
        if write_idx - offset + length < write_idx {
          mem.copy(&output[write_idx], &output[write_idx - offset], length)
        } else {
          for i in 0..<length {
            output[write_idx+i] = output[write_idx - offset + i]
          }
        }
        write_idx += length
      } else {
        length := int(length) + MIN_LITERAL_LENGTH
        mem.copy(&output[write_idx], &input[read_idx], length)
        write_idx += length
        read_idx += length
      }
    }
  }
