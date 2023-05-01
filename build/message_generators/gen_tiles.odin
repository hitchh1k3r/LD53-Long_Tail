package message_generators

import "core:fmt"
import "core:mem"
import "core:odin/ast"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"

import "build:meta"
import "build:beard"

tile_types : [dynamic]string

get_tile_types :: proc(root_declarations : map[string]meta.MetaDecl) -> bool {
  PROFILE(#procedure)
  for field in root_declarations["Tile"].value.(^ast.Enum_Type).fields {
    #partial switch field in field.derived {
      case ^ast.Ident:
        append(&tile_types, field.name)
      case ^ast.Field_Value:
        append(&tile_types, field.field.derived.(^ast.Ident).name)
    }
  }
  return true
}

gen_tiles :: proc(root_declarations : map[string]meta.MetaDecl) {
  PROFILE(#procedure)
  has_error := !get_tile_types(root_declarations)

  data := make([]u8, 2 * mem.Gigabyte)
  defer delete(data)
  arena : mem.Arena
  mem.arena_init(&arena, data)
  arena_allocator := mem.arena_allocator(&arena)
  {
    context.allocator = arena_allocator

    // Gather Tile Messages:
      TileProc :: struct { tile_name : string, meta_proc : meta.MetaProc }
      tile_messages : map[string]map[string]TileProc
      for decl_name, declaration in root_declarations {
        if att := meta.find_meta_attribute(declaration.attrs, "tile_message"); att.key.text != "" {
          if att.value.text != "" {
            tile_name := ""
            message_name := att.value.text
            if slash_idx := strings.index_byte(att.value.text, '/'); slash_idx >= 0 {
              tile_name = att.value.text[:slash_idx]
              message_name = att.value.text[slash_idx+1:]
            }
            if tile_name != "" {
              valid := false
              for tile in tile_types {
                if tile == tile_name {
                  valid = true
                  break
                }
              }
              if !valid {
                fmt.eprintf("%v(%v:%v) Meta Error: '%v' is not a valid Tile value\n", declaration.file.fullpath, att.value.line_num, att.value.col_num, tile_name)
                has_error = true
              }
            }
            proc_type : ^ast.Proc_Type
            if pt, ok := declaration.type.(^ast.Proc_Type); ok {
              proc_type = pt
            } else if pl, ok := declaration.value.(^ast.Proc_Lit); ok {
              proc_type = pl.type
            }
            if proc_type != nil {
              new_proc := meta.ast_to_meta_proc(proc_type, declaration.file)

              if tile_name == "" {
                // Tile
                if len(new_proc.params) < 1 {
                  fmt.eprintf("%v(%v:%v) Meta Error: procedure requires Tile parameter\n", declaration.file.fullpath, proc_type.pos.line, proc_type.pos.column)
                  has_error = true
                } else if new_proc.params[0].type != "Tile" {
                  line, col : int
                  if new_proc.params[0].field.type != nil {
                    line, col = new_proc.params[0].field.type.pos.line, new_proc.params[0].field.type.pos.column
                  } else {
                    line, col = new_proc.params[0].field.names[0].pos.line, new_proc.params[0].field.names[0].pos.column
                  }
                  fmt.eprintf("%v(%v:%v) Meta Error: '%v' is not Tile\n", declaration.file.fullpath, line, col, new_proc.params[0].type)
                  has_error = true
                }
                // TilePos
                if len(new_proc.params) < 2 {
                  fmt.eprintf("%v(%v:%v) Meta Error: procedure requires TilePos parameter\n", declaration.file.fullpath, proc_type.pos.line, proc_type.pos.column)
                  has_error = true
                } else if new_proc.params[1].type != "TilePos" {
                  line, col : int
                  if new_proc.params[1].field.type != nil {
                    line, col = new_proc.params[1].field.type.pos.line, new_proc.params[1].field.type.pos.column
                  } else {
                    line, col = new_proc.params[1].field.names[0].pos.line, new_proc.params[1].field.names[0].pos.column
                  }
                  fmt.eprintf("%v(%v:%v) Meta Error: '%v' is not TilePos\n", declaration.file.fullpath, line, col, new_proc.params[1].type)
                  has_error = true
                }
              } else {
                // TilePos
                if len(new_proc.params) < 1 {
                  fmt.eprintf("%v(%v:%v) Meta Error: procedure requires TilePos parameter\n", declaration.file.fullpath, proc_type.pos.line, proc_type.pos.column)
                  has_error = true
                } else if new_proc.params[0].type != "TilePos" {
                  line, col : int
                  if new_proc.params[0].field.type != nil {
                    line, col = new_proc.params[0].field.type.pos.line, new_proc.params[0].field.type.pos.column
                  } else {
                    line, col = new_proc.params[0].field.names[0].pos.line, new_proc.params[0].field.names[0].pos.column
                  }
                  fmt.eprintf("%v(%v:%v) Meta Error: '%v' is not TilePos\n", declaration.file.fullpath, line, col, new_proc.params[0].type)
                  has_error = true
                }
              }

              for result in new_proc.results
              {
                if result_type, ok := meta.ast_resolve_constant(result.field.type.derived, root_declarations); ok {
                  if result.name == "_" || result.name == "" {
                    fmt.eprintf("%v(%v:%v) Meta Error: result must be named\n", declaration.file.fullpath, result.field.type.pos.line, result.field.type.pos.column)
                    has_error = true
                  }
                  if _, ok := result_type.(^ast.Bit_Set_Type); ok {
                    // it's a valid bit_set type
                  } else {
                    fmt.eprintf("%v(%v:%v) Meta Error: result must be a bit_set\n", declaration.file.fullpath, result.field.type.pos.line, result.field.type.pos.column)
                    has_error = true
                  }
                } else {
                  fmt.eprintf("%v(%v:%v) Meta Error: could not resolve type\n", declaration.file.fullpath, result.field.type.pos.line, result.field.type.pos.column)
                  has_error = true
                }
              }

              if message_name not_in tile_messages {
                tile_messages[message_name] = {}
              }
              if "" not_in tile_messages[message_name] {
                (&tile_messages[message_name])[""] = {}
              }

              param_start_idx := (len(tile_name) > 0) ? 1 : 2
              has_error |= add_params(new_proc, &(&tile_messages[message_name][""]).meta_proc, param_start_idx, declaration.file, "tile", message_name)
              has_error |= add_results(new_proc, &(&tile_messages[message_name][""]).meta_proc, declaration.file, "tile", message_name)

              (&tile_messages[message_name])[decl_name] = TileProc{ tile_name, new_proc }
            } else {
              fmt.eprintf("%v(%v:%v) Meta Error: 'tile_message' can only be applied to a procedures\n", declaration.file.fullpath, att.key.line_num, att.key.col_num)
              has_error = true
            }
          } else {
            fmt.eprintf("%v(%v:%v) Meta Error: 'tile_message' expects a string literal parameter\n", declaration.file.fullpath, att.key.line_num, att.key.col_num)
            has_error = true
          }
        }
      }

    // Exit Early If Errored:
      if has_error {
        os.exit(1)
      }

    // Write Tiles File:
      beard_tiles := make(beard.Slice, len(tile_types))
      for tile, tile_idx in tile_types {
        beard_tiles[tile_idx] = beard.Map{ "tile_name" = tile }
      }
      beard_messages := make(beard.Slice, len(tile_messages))
      message_idx : int
      for message_name, message_procs in tile_messages {
        defer message_idx += 1

        unique_fields : [dynamic]string = { "tile_type", "tile_pos" }
        param_lookup : map[string]string
        result_lookup : map[string]string
        get_unique_string :: proc(name : string, fields : []string, allocator := context.allocator) -> string {
          PROFILE(#procedure, name)
          context.allocator = allocator
          search_name := name
          idx := 0
          unique_check: for {
            if idx > 0 {
              search_name = fmt.tprintf("%v_%v", name, idx)
            }
            idx += 1
            for field in fields {
              if search_name == field {
                continue unique_check
              }
            }
            return fmt.aprint(search_name)
          }
        }

        beard_proto_params := make(beard.Slice, len(message_procs[""].meta_proc.params))
        proto_params := meta.sort_params(message_procs[""].meta_proc.params[:])
        defer delete(proto_params)
        for param, param_idx in proto_params {
          param := param
          unique_name := get_unique_string(param.name, unique_fields[:])
          append(&unique_fields, unique_name)
          param_lookup[param.name] = unique_name
          param.name = unique_name
          beard_proto_params[param_idx] = beard.Map{ "param_name" = param.name, "param_decl" = meta.field_to_declaration_string(param), "not_first" = (param_idx > 0) }
        }

        beard_proto_results := make(beard.Slice, len(message_procs[""].meta_proc.results))
        proto_results := meta.sort_params(message_procs[""].meta_proc.results[:])
        defer delete(proto_results)
        for result, result_idx in proto_results {
          result := result
          unique_name := get_unique_string(result.name, unique_fields[:])
          append(&unique_fields, unique_name)
          result_lookup[result.name] = unique_name
          result.name = unique_name
          beard_proto_results[result_idx] = beard.Map{ "result_name" = result.name, "result_decl" = meta.field_to_declaration_string(result), "not_first" = (result_idx > 0) }
        }

        beard_procs := make(beard.Slice, len(message_procs)-1)
        proc_idx : int
        for proc_name, proc_data in message_procs {
          if proc_name == "" {
            continue
          }
          defer proc_idx += 1

          param_start_idx := (len(proc_data.tile_name) > 0) ? 1 : 2
          beard_params := make(beard.Slice, len(proc_data.meta_proc.params)-param_start_idx)
          for param, param_idx in proc_data.meta_proc.params[param_start_idx:] {
            param := param
            param.name = param_lookup[param.name]
            beard_params[param_idx] = beard.Map{ "param_name" = param.name, "param_decl" = meta.field_to_declaration_string(param), "not_first" = (param_idx > 0) }
          }

          beard_results := make(beard.Slice, len(proc_data.meta_proc.results))
          for result, result_idx in proc_data.meta_proc.results {
            result := result
            result.name = result_lookup[result.name]
            beard_results[result_idx] = beard.Map{ "result_name" = result.name, "result_decl" = meta.field_to_declaration_string(result), "not_first" = (result_idx > 0) }
          }

          beard_procs[proc_idx] = beard.Map{
            "tile_name" = proc_data.tile_name,
            "is_generic" = len(proc_data.tile_name) == 0,
            "not_generic" = len(proc_data.tile_name) > 0,
            "proc_name" = proc_name,
            "params" = beard_params,
            "has_results" = (len(beard_results) > 0),
            "results" = beard_results,
          }
        }

        beard_messages[message_idx] = beard.Map{
          "message_name" = message_name,
          "message_slashes" = slashes[20+len(message_name):],
          "safe_tile_type_name" = "tile_type",
          "safe_tile_pos_name" = "tile_pos",
          "params" = beard_proto_params,
          "has_results" = (len(beard_proto_results) > 0),
          "results" = beard_proto_results,
          "procs" = beard_procs,
        }
      }

      tile_data : beard.Node = beard.Map{
        "tiles" = beard_tiles,
        "messages" = beard_messages,
      }

      tile_src := beard.process(TEMPLATE_TILE_FILE, tile_data)
      if !os.write_entire_file("./src/game/tiles_.odin", transmute([]u8)(tile_src)) {
        fmt.eprintln("Could not write tiles_.odin")
        os.exit(1)
      }
  }
}

@(private="file")
TEMPLATE_TILE_FILE :: `package game

////////////////////////////////////////////////////////////////////////////////////////////////////
///// This file is automatically generated, do not edit it by hand or changes will be erased!  /////
////////////////////////////////////////////////////////////////////////////////////////////////////
{{#messages}}

  // Tile Message "{{message_name}}" /{{message_slashes}}

    tile_{{message_name}} :: proc{ tile_{{message_name}}_at }

    tile_{{message_name}}_at :: proc({{safe_tile_pos_name}} : TilePos{{#params}}, {{param_decl}}{{/params}}){{#has_results}} -> ({{#results}}{{#not_first}}, {{/not_first}}{{result_decl}}{{/results}}){{/has_results}} {
      {{safe_tile_type_name}} := world_get_tile_at({{safe_tile_pos_name}})
      #partial switch {{safe_tile_type_name}} {
        {{#procs}}
          {{#is_generic}}
            case:
              {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}{{result_name}}{{/results}} = {{/has_results}}{{proc_name}}({{safe_tile_type_name}}, {{safe_tile_pos_name}}{{#params}}, {{param_name}}{{/params}})
          {{/is_generic}}
          {{#not_generic}}
            case .{{tile_name}}:
              {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}{{result_name}}{{/results}} = {{/has_results}}{{proc_name}}({{safe_tile_pos_name}}{{#params}}, {{param_name}}{{/params}})
          {{/not_generic}}
        {{/procs}}
      }
      return
    }
{{/messages}}
`
