package meta_resources

import "core:bytes"
import "core:crypto/sha1"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"

import "../beard"

gen_resources :: proc(force_rebuild : bool) {
  PROFILE(#procedure)
  all_hash : string
  defer delete(all_hash)
  file_hashes : map[string]string
  defer {
    for key, hash in &file_hashes {
      delete(key)
      delete(hash)
    }
  }
  if !force_rebuild
  {
    hash_cache, ok := os.read_entire_file("artifacts/resources/cache")
    defer delete(hash_cache)
    if ok {
      hash_cache := string(hash_cache)
      key : string
      i := 0
      for line in strings.split_iterator(&hash_cache, "\n") {
        if i == 0 {
          all_hash = strings.clone(line)
        } else if i % 2 == 1 {
          key = strings.clone(line)
        } else {
          file_hashes[key] = strings.clone(line)
        }
        i += 1
      }
    }
  }

  hash_ctx : sha1.Sha1_Context
  sha1.init(&hash_ctx)

  ResourceType :: struct {
    title : string,
    upper : string,
  }

  all_resource_paths : map[ResourceType][dynamic]string
  defer {
    for _, arr in all_resource_paths {
      delete(arr)
    }
    delete(all_resource_paths)
  }

  IMAGE_TYPE :: ResourceType{ "Image", "IMAGE" }
  all_resource_paths[IMAGE_TYPE] = {}
  LEVEL_TYPE :: ResourceType{ "Level", "LEVEL" }
  all_resource_paths[LEVEL_TYPE] = {}
  SOUND_TYPE :: ResourceType{ "Sound", "SOUND" }
  all_resource_paths[SOUND_TYPE] = {}
  // MODEL_TYPE :: ResourceType{ "Model", "MODEL" }
  // all_resource_paths[MODEL_TYPE] = {}

  extensions := map[string]ResourceType{
    ".png"  = IMAGE_TYPE,
    ".ldtk"  = LEVEL_TYPE,
    ".wav"  = SOUND_TYPE,
    ".mp3"  = SOUND_TYPE,
    // ".glb"  = MODEL_TYPE,
  }

  Processor :: #type proc([]u8) -> []u8

  asset_processors := map[string]Processor{
    ".png"  = load_png,
    ".ldtk"  = load_ldtk,
  }

  BASE_PATH :: "res/"
  scan_path(BASE_PATH, &hash_ctx, all_resource_paths, extensions)
  scan_path :: proc(path : string, hash_ctx : ^sha1.Sha1_Context, all_resource_paths : map[ResourceType][dynamic]string, extensions : map[string]ResourceType) {
    if fh, err := os.open(path); err == os.ERROR_NONE {
      PROFILE("find_resources()")
      defer os.close(fh)
      if files, err := os.read_dir(fh, -1); err == os.ERROR_NONE {
        defer delete(files)
        for file in files {
          file_local_path : string
          if len(path) > len(BASE_PATH) {
            file_local_path = fmt.tprintf("%v/%v", path[len(BASE_PATH):], file.name)
          } else {
            file_local_path = fmt.tprintf("%v", file.name)
          }
          if file_local_path != "raw" {
            if file.is_dir {
              os.make_directory(fmt.tprintf("artifacts/resources/%v", file_local_path))
              scan_path(fmt.tprintf("res/%v", file_local_path), hash_ctx, all_resource_paths, extensions)
            } else {
              for extension, type in extensions {
                if strings.has_suffix(file_local_path, extension) {
                  size_bytes := transmute([size_of(i64)]u8)file.size
                  time_bytes := transmute([size_of(time.Time)]u8)file.modification_time
                  sha1.update(hash_ctx, transmute([]u8)file_local_path)
                  sha1.update(hash_ctx, size_bytes[:])
                  sha1.update(hash_ctx, time_bytes[:])
                  append(&all_resource_paths[type], strings.clone(file_local_path))
                  break
                }
              }
            }
          }
        }
      }
    }
  }

  hash : [sha1.DIGEST_SIZE]byte
  sha1.final(&hash_ctx, hash[:])

  if string(all_hash) == string(hash[:]) {
    fmt.printf("  assets have not changed, reusing last asset.pak\n")
    return
  }

  hash_file, errhf := os.open("artifacts/resources/cache", os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
  defer os.close(hash_file)
  if errhf != os.ERROR_NONE {
    fmt.eprintln("Could not write resource cache database")
    os.exit(1)
  }
  os.write(hash_file, hash[:])

  resources_file, errrf := os.open("artifacts/resources/asset.pak", os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
  defer os.close(resources_file)
  if errrf != os.ERROR_NONE {
    fmt.eprintln("Could not write asset.pak")
    os.exit(1)
  }

  BACKREF_LENGTH_FLAG :: 0b10000000_00000000

  MIN_BACKREF_DISTANCE :: int(1)
  MAX_BACKREF_DISTANCE :: int(max(u16)) + MIN_BACKREF_DISTANCE
  MIN_BACKREF_LENGTH :: int(7)
  MAX_BACKREF_LENGTH :: int(max(u16) >> 1) + MIN_BACKREF_LENGTH

  MIN_LITERAL_LENGTH :: int(1)
  MAX_LITERAL_LENGTH :: int(max(u16) >> 1) + MIN_LITERAL_LENGTH

  @(static) rf_offset : int
  rf_offset = 0

  @(static) cache_file : os.Handle
  @(static) write_file : os.Handle
  write_file = resources_file
  write_literal :: proc(input_stream : []u8, start, end : int) {
    PROFILE(#procedure)
    rf_offset += 2 + (end - start)
    len_bytes := transmute([2]u8)(u16le((end - start) - MIN_LITERAL_LENGTH))
    if _, err := os.write(write_file, len_bytes[:]); err != os.ERROR_NONE {
      fmt.eprintln("\n  Could not write a file to asset.pak")
      os.exit(1)
    }
    if _, err := os.write(write_file, input_stream[start:end]); err != os.ERROR_NONE {
      fmt.eprintln("\n  Could not write a file to asset.pak")
      os.exit(1)
    }
    if _, err := os.write(cache_file, len_bytes[:]); err != os.ERROR_NONE {
      fmt.eprintln("\n  Could not write a file to cache")
      os.exit(1)
    }
    if _, err := os.write(cache_file, input_stream[start:end]); err != os.ERROR_NONE {
      fmt.eprintln("\n  Could not write a file to cache")
      os.exit(1)
    }
  }

  write_backref :: proc(input_stream : []u8, input_index : ^int, offset, length : int) {
    PROFILE(#procedure)
    rf_offset += 4
    length := min(length, MAX_BACKREF_LENGTH)
    ref_bytes := transmute([4]u8)([2]u16le{ 0b10000000_00000000 | u16le(length - MIN_BACKREF_LENGTH), u16le(offset - MIN_BACKREF_DISTANCE) })
    if _, err := os.write(write_file, ref_bytes[:]); err != os.ERROR_NONE {
      fmt.eprintln("\n  Could not write a file to asset.pak")
      os.exit(1)
    }
    if _, err := os.write(cache_file, ref_bytes[:]); err != os.ERROR_NONE {
      fmt.eprintln("\n  Could not write a file to cache")
      os.exit(1)
    }
    input_index^ += length
  }

  find_longest_backref :: proc(input_stream : []u8, input_index : int) -> (max_backref := 0, max_len := int(MIN_BACKREF_LENGTH-1)) {
    PROFILE(#procedure)
    if input_index+max_len >= len(input_stream) {
      return
    }
    window := input_stream[max(input_index-int(MIN_BACKREF_LENGTH), 0):min(input_index+max_len-max_backref, len(input_stream))]
    window_back_dist := min(int(MIN_BACKREF_LENGTH), input_index)
    offset := bytes.last_index(window, input_stream[input_index:input_index+max_len+1])
    for offset >= 0 {
      max_backref = window_back_dist - offset
      max_len += 1
      for i in input_index+max_len..<len(input_stream) {
        if input_stream[i] == input_stream[i - max_backref] {
          max_len += 1
        } else {
          break
        }
      }
      if input_index+max_len >= len(input_stream) {
        return
      }
      window = input_stream[max(input_index-int(MIN_BACKREF_LENGTH), 0):min(input_index+max_len-1-max_backref, len(input_stream))]
      offset = bytes.last_index(window, input_stream[input_index:input_index+max_len+1])
    }
    return
  }


  type_idx : int
  beard_asset_types := make(beard.Slice, len(all_resource_paths))
  for type in all_resource_paths
  {
    PROFILE("process_type()", type.title)
    fmt.printf("  %v:", type.title)
    beard_type_resources := make(beard.Slice, len(all_resource_paths[type]))

    resource_idx : int
    for file, i in all_resource_paths[type] {
      PROFILE("process_file()", file)
      if i > 0 {
        fmt.print(",")
      }
      fmt.printf(" %v", file)
      start_offset := rf_offset
      defer resource_idx += 1
      if bytes, ok := os.read_entire_file(resolve_path("res/", file)); ok {
        file_content := bytes
        defer {
          if raw_data(bytes) != raw_data(file_content) {
            delete(file_content)
          }
          delete(bytes)
        }

        os.write_byte(hash_file, '\n')
        hash := sha1.hash_bytes(file_content)
        os.write_string(hash_file, file)
        os.write_byte(hash_file, '\n')
        os.write(hash_file, hash[:])
        write_to_file: {
          if cache_hash, ok := file_hashes[file]; ok && string(cache_hash) == string(hash[:]) {
            if cache_data, ok := os.read_entire_file(fmt.tprintf("artifacts/resources/%v", file)); ok {
              // Cached:
              uncompressed_size := int((transmute([^]i32le)raw_data(cache_data[:4]))[0])
              rf_offset += len(cache_data[4:])
              if _, err := os.write(write_file, cache_data[4:]); err != os.ERROR_NONE {
                fmt.eprintln("\n  Could not write a file to resources")
                os.exit(1)
              }

              if len(bytes) != len(file_content) {
                fmt.printf("(cache/%.02v%%/%.02v%%)", 100*(f32(rf_offset-start_offset)/f32(len(file_content))), 100*(f32(rf_offset-start_offset)/f32(len(bytes))))
              } else {
                fmt.printf("(cache/%.02v%%)", 100*(f32(rf_offset-start_offset)/f32(len(file_content))))
              }

              beard_type_resources[resource_idx] = beard.Map{ "path" = file, "ada_path" = ada_case(file[:strings.last_index_byte(file, '.')]), "offset" = fmt.aprintf("%v", start_offset), "length" = fmt.aprintf("%v", uncompressed_size), "actual_size" = fmt.aprintf("%v", rf_offset-start_offset) }

              break write_to_file
            }
          }

          // No Cache:
          err : os.Errno
          if cache_file, err = os.open(fmt.tprintf("artifacts/resources/%v", file), os.O_WRONLY | os.O_CREATE | os.O_TRUNC); err != os.ERROR_NONE {
            fmt.eprintln("\n  Could not create cache file")
            os.exit(1)
          }
          for extension, processor in asset_processors {
            if strings.has_suffix(file, extension) {
              file_content = processor(bytes)
            }
          }

          length_bytes := transmute([4]u8)(i32le(len(file_content)))
          if _, err := os.write(cache_file, length_bytes[:]); err != os.ERROR_NONE {
            fmt.eprintln("\n  Could not write a file to cache")
            os.exit(1)
          }

          literal_index := 0
          input_index := 1
          for input_index < len(file_content) {
            max_backref, max_len := find_longest_backref(file_content, input_index)
            if max_len >= int(MIN_BACKREF_LENGTH) {
              if literal_index >= 0 {
                write_literal(file_content, literal_index, input_index)
                literal_index = -1
              }
              write_backref(file_content, &input_index, max_backref, max_len)
              continue
            }
            if literal_index >= 0 {
              if input_index - literal_index >= int(MAX_LITERAL_LENGTH) {
                write_literal(file_content, literal_index, input_index)
                literal_index = input_index
              }
            } else {
              literal_index = input_index
            }
            input_index += 1
          }
          if literal_index >= 0 {
            write_literal(file_content, literal_index, len(file_content))
          }
          os.close(cache_file)
          if len(bytes) != len(file_content) {
            fmt.printf("(%.02v%%/%.02v%%)", 100*(f32(rf_offset-start_offset)/f32(len(file_content))), 100*(f32(rf_offset-start_offset)/f32(len(bytes))))
          } else {
            fmt.printf("(%.02v%%)", 100*(f32(rf_offset-start_offset)/f32(len(file_content))))
          }

          beard_type_resources[resource_idx] = beard.Map{ "path" = file, "ada_path" = ada_case(file[:strings.last_index_byte(file, '.')]), "offset" = fmt.aprintf("%v", start_offset), "length" = fmt.aprintf("%v", len(file_content)), "actual_size" = fmt.aprintf("%v", (rf_offset-start_offset)) }
        }
      }
    }

    fmt.print("\n")

    beard_asset_types[type_idx] = beard.Map{
      "title_type" = type.title,
      "upper_type" = type.upper,
      "resources" = beard_type_resources,
    }
    type_idx += 1
  }

  resources_data : beard.Node = beard.Map{
    "asset_types" = beard_asset_types,
  }

  asset_index_src := beard.process(TEMPLATE_ASSET_INDEX_FILE, resources_data)
  if !os.write_entire_file("src/platform/asset_index_.odin", transmute([]u8)(asset_index_src)) {
    fmt.eprintln("Could not write asset_index_.odin")
    os.exit(1)
  }
}

/*
asset_types[
  title_type"
  upper_type"
  resources[
    path"
    ada_path"
    offset"
    length"
*/

@(private="file")
TEMPLATE_ASSET_INDEX_FILE :: `package platform

////////////////////////////////////////////////////////////////////////////////////////////////////
///// This file is automatically generated, do not edit it by hand or changes will be erased!  /////
////////////////////////////////////////////////////////////////////////////////////////////////////

ResourceLocation :: struct {
  offset : i64,
  compressed_length : i64,
  uncompressed_length : i64,
}

ResourceId :: union {
  {{#asset_types}}
    Resource{{title_type}},
  {{/asset_types}}
}

resource_location :: proc(id : ResourceId) -> ResourceLocation {
  switch id in id {
    {{#asset_types}}
      case Resource{{title_type}}:
        return {{upper_type}}_INDEX[id]
    {{/asset_types}}
  }
  return {}
}
{{#asset_types}}

  ////////////////////////////////////////////////////////////////////////////////////////////////////

  Resource{{title_type}} :: enum {
    {{#resources}}
      {{ada_path}},
    {{/resources}}
  }

  @(private="file")
  {{upper_type}}_INDEX := [Resource{{title_type}}]ResourceLocation {
    {{#resources}}
      .{{ada_path}} = { {{offset}}, {{actual_size}}, {{length}} },
    {{/resources}}
  }
{{/asset_types}}
`

////////////////////////////////////////////////////////////////////////////////////////////////////

@(deferred_out=delete_str)
resolve_path :: proc(path : string, file : string) -> string {
  PROFILE(#procedure, path)
  return strings.concatenate({path, file})
}

delete_str :: proc(str : string) {
  PROFILE(#procedure)
  delete(str)
}

ada_case :: proc(str : string) -> string {
  PROFILE(#procedure)
  backing := make([]u8, len(str))
  first := true
  for ch, i in str {
    switch ch {
      case 'a'..='z':
        if first {
          first = false
          backing[i] = u8(ch + ('A'-'a'))
        } else {
          backing[i] = u8(ch)
        }
      case 'A'..='Z':
        if first {
          first = false
          backing[i] = u8(ch)
        } else {
          backing[i] = u8(ch + ('a'-'A'))
        }
      case '0'..='9':
        if i == 0 {
          backing[i] = '_'
        } else {
          backing[i] = u8(ch)
        }
        first = true
      case:
        backing[i] = '_'
        first = true
    }
  }
  return string(backing)
}
