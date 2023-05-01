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

entity_types : [dynamic]string

slashes := "////////////////////////////////////////////////////////////////////////////////////////////////////"

get_entity_types :: proc(root_declarations : map[string]meta.MetaDecl) -> bool {
  PROFILE(#procedure)
  ok := true
  for decl_name, declaration in root_declarations {
    if att := meta.find_meta_attribute(declaration.attrs, "entity_type"); att.key.text != "" {
      if att.value.text == "" {
        if _, ok := declaration.value.(^ast.Struct_Type); ok {
          append(&entity_types, decl_name)
        } else {
          line, col := meta.ast_get_line_col(declaration.value)
          if line == 0 && col == 0 {
            line = att.key.line_num
            col = att.key.col_num
          }
          fmt.eprintf("%v(%v:%v) Meta Error: 'entity_type' can only be applied to a struct type\n", declaration.file.fullpath, line, col)
          ok = false
        }
      } else {
        fmt.eprintf("%v(%v:%v) Meta Error: 'entity_type' expects no parameter\n", declaration.file.fullpath, att.value.line_num, att.value.col_num)
        ok = false
      }
    }
  }
  return ok
}

gen_entities :: proc(root_declarations : map[string]meta.MetaDecl) {
  PROFILE(#procedure)
  has_error := !get_entity_types(root_declarations)

  data := make([]u8, 2 * mem.Gigabyte)
  defer delete(data)
  arena : mem.Arena
  mem.arena_init(&arena, data)
  arena_allocator := mem.arena_allocator(&arena)
  {
    context.allocator = arena_allocator

    // Gather Entity Messages:
      entity_messages : map[string]map[string]meta.MetaProc
      for decl_name, declaration in root_declarations {
        if att := meta.find_meta_attribute(declaration.attrs, "entity_message"); att.key.text != "" {
          if att.value.text != "" {
            proc_type : ^ast.Proc_Type
            if pt, ok := declaration.type.(^ast.Proc_Type); ok {
              proc_type = pt
            } else if pl, ok := declaration.value.(^ast.Proc_Lit); ok {
              proc_type = pl.type
            }
            if proc_type != nil {
              new_proc := meta.ast_to_meta_proc(proc_type, declaration.file)

              if len(new_proc.params) < 1 || len(new_proc.params[0].type) <= 1 || new_proc.params[0].type[0] != '^' {
                if len(new_proc.params) >= 1 {
                  line, col : int
                  if new_proc.params[0].field.type != nil {
                    line, col = new_proc.params[0].field.type.pos.line, new_proc.params[0].field.type.pos.column
                  } else {
                    line, col = new_proc.params[0].field.names[0].pos.line, new_proc.params[0].field.names[0].pos.column
                  }
                  fmt.eprintf("%v(%v:%v) Meta Error: not a pointer to a valid entity type\n", declaration.file.fullpath, line, col)
                } else {
                  fmt.eprintf("%v(%v:%v) Meta Error: procedure requires entity type pointer parameter\n", declaration.file.fullpath, proc_type.pos.line, proc_type.pos.column)
                }
                has_error = true
              } else {
                valid := false
                for entity_type in entity_types {
                  if new_proc.params[0].type[1:] == entity_type {
                    valid = true
                    break
                  }
                }
                if !valid {
                  fmt.eprintf("%v(%v:%v) Meta Error: not a valid entity type pointer\n", declaration.file.fullpath, new_proc.params[0].field.type.pos.line, new_proc.params[0].field.type.pos.column)
                  has_error = true
                }
              }
              for result in new_proc.results
              {
                if result.name == "_" || result.name == "" {
                  fmt.eprintf("%v(%v:%v) Meta Error: result must be named\n", declaration.file.fullpath, result.field.type.pos.line, result.field.type.pos.column)
                  has_error = true
                }
                if result_type, ok := meta.ast_resolve_constant(result.field.type.derived, root_declarations); ok {
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

              if att.value.text not_in entity_messages {
                entity_messages[att.value.text] = {}
              }
              if "" not_in entity_messages[att.value.text] {
                (&entity_messages[att.value.text])[""] = {}
              }

              has_error |= add_params(new_proc, &entity_messages[att.value.text][""], 1, declaration.file, "entity", att.value.text)
              has_error |= add_results(new_proc, &entity_messages[att.value.text][""], declaration.file, "entity", att.value.text)

              (&entity_messages[att.value.text])[decl_name] = new_proc
            } else {
              fmt.eprintf("%v(%v:%v) Meta Error: 'entity_message' can only be applied to a procedures\n", declaration.file.fullpath, att.key.line_num, att.key.col_num)
              has_error = true
            }
          } else {
            fmt.eprintf("%v(%v:%v) Meta Error: 'entity_message' expects a string literal parameter\n", declaration.file.fullpath, att.key.line_num, att.key.col_num)
            has_error = true
          }
        }
      }

    // Exit Early If Errored:
      if has_error {
        os.exit(1)
      }

    // Write Entities File:
      beard_entities := make(beard.Slice, len(entity_types))
      for entity, entity_idx in entity_types {
        beard_entities[entity_idx] = beard.Map{ "type_name" = entity }
      }
      beard_messages := make(beard.Slice, len(entity_messages))
      message_idx : int
      for message_name, message_procs in entity_messages {
        defer message_idx += 1

        unique_fields : [dynamic]string = { "entity", "entity_handle", "entity_list", "tile_pos", "entity_backing" }
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

        beard_proto_params := make(beard.Slice, len(message_procs[""].params))
        proto_params := meta.sort_params(message_procs[""].params[:])
        defer delete(proto_params)
        for param, param_idx in proto_params {
          param := param
          unique_name := get_unique_string(param.name, unique_fields[:])
          append(&unique_fields, unique_name)
          param_lookup[param.name] = unique_name
          param.name = unique_name
          beard_proto_params[param_idx] = beard.Map{ "param_name" = param.name, "param_decl" = meta.field_to_declaration_string(param), "not_first" = (param_idx > 0) }
        }

        beard_proto_results := make(beard.Slice, len(message_procs[""].results))
        proto_results := meta.sort_params(message_procs[""].results[:])
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

          beard_params := make(beard.Slice, len(proc_data.params)-1)
          for param, param_idx in proc_data.params[1:] {
            param := param
            param.name = param_lookup[param.name]
            beard_params[param_idx] = beard.Map{ "param_name" = param.name, "param_decl" = meta.field_to_declaration_string(param), "not_first" = (param_idx > 0) }
          }

          beard_results := make(beard.Slice, len(proc_data.results))
          for result, result_idx in proc_data.results {
            result := result
            result.name = result_lookup[result.name]
            beard_results[result_idx] = beard.Map{ "result_name" = result.name, "result_decl" = meta.field_to_declaration_string(result), "not_first" = (result_idx > 0) }
          }

          beard_procs[proc_idx] = beard.Map{
            "entity_type" = proc_data.params[0].type[1:],
            "proc_name" = proc_name,
            "params" = beard_params,
            "has_results" = (len(beard_results) > 0),
            "results" = beard_results,
          }
        }

        beard_messages[message_idx] = beard.Map{
          "message_name" = message_name,
          "message_slashes" = slashes[22+len(message_name):],
          "safe_entity_name" = "entity",
          "safe_entity_handle_name" = "entity_handle",
          "safe_entity_list_name" = "entity_list",
          "safe_tile_pos_name" = "tile_pos",
          "params" = beard_proto_params,
          "has_results" = (len(beard_proto_results) > 0),
          "results" = beard_proto_results,
          "procs" = beard_procs,
        }
      }

      entity_data : beard.Node = beard.Map{
        "entities" = beard_entities,
        "messages" = beard_messages,
      }

      entity_src := beard.process(TEMPLATE_ENTITY_FILE, entity_data)
      if !os.write_entire_file("./src/game/entities_.odin", transmute([]u8)(entity_src)) {
        fmt.eprintln("Could not write entities_.odin")
        os.exit(1)
      }
  }
}

@(private="file")
TEMPLATE_ENTITY_FILE :: `package game

import "project:graphics"

////////////////////////////////////////////////////////////////////////////////////////////////////
///// This file is automatically generated, do not edit it by hand or changes will be erased!  /////
////////////////////////////////////////////////////////////////////////////////////////////////////

// Entity Types ////////////////////////////////////////////////////////////////////////////////////

  Entity :: union {
    {{#entities}}
      {{type_name}},
    {{/entities}}
  }

  get_base :: proc(entity : ^Entity) -> ^EntityBase {
    if entity == nil {
      return nil
    }
    switch entity in entity {
      {{#entities}}
        case {{type_name}}:
          return &entity.base
      {{/entities}}
    }
    return nil
  }
{{#messages}}

  // Entity Message "{{message_name}}" /{{message_slashes}}

    entity_{{message_name}} :: proc{ entity_{{message_name}}_ptr, entity_{{message_name}}_handle, entity_{{message_name}}_list, entity_{{message_name}}_at }

    entity_{{message_name}}_ptr :: proc({{safe_entity_name}} : ^Entity{{#params}}, {{param_decl}}{{/params}}){{#has_results}} -> ({{#results}}{{#not_first}}, {{/not_first}}{{result_decl}}{{/results}}){{/has_results}} {
      #partial switch {{safe_entity_name}} in {{safe_entity_name}} {
        {{#procs}}
          case {{entity_type}}:
            {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}{{result_name}}{{/results}} = {{/has_results}}{{proc_name}}(&{{safe_entity_name}}{{#params}}, {{param_name}}{{/params}})
        {{/procs}}
      }
      return
    }

    entity_{{message_name}}_handle :: proc({{safe_entity_handle_name}} : EntityHandle{{#params}}, {{param_decl}}{{/params}}){{#has_results}} -> ({{#results}}{{#not_first}}, {{/not_first}}{{result_decl}}{{/results}}){{/has_results}} {
      {{safe_entity_name}} := entity_lookup[{{safe_entity_handle_name}}]
      if {{safe_entity_name}} != nil {
        {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}{{result_name}}{{/results}} = {{/has_results}}entity_{{message_name}}_ptr({{safe_entity_name}}{{#params}}, {{param_name}}{{/params}})
      }
      return
    }

    entity_{{message_name}}_list :: proc({{safe_entity_list_name}} : []^Entity{{#params}}, {{param_decl}}{{/params}}){{#has_results}} -> ({{#results}}{{#not_first}}, {{/not_first}}{{result_decl}}{{/results}}){{/has_results}} {
      for {{safe_entity_name}} in {{safe_entity_list_name}} {
        if {{safe_entity_name}} != nil {
          {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}temp_{{result_name}}{{/results}} := {{/has_results}}entity_{{message_name}}_ptr({{safe_entity_name}}{{#params}}, {{param_name}}{{/params}})
          {{#results}}
            {{result_name}} |= temp_{{result_name}}
          {{/results}}
        }
      }
      return
    }

    entity_{{message_name}}_all :: proc({{#params}}{{#not_first}}, {{/not_first}}{{param_decl}}{{/params}}){{#has_results}} -> ({{#results}}{{#not_first}}, {{/not_first}}{{result_decl}}{{/results}}){{/has_results}} {
      for {{safe_entity_name}}, entity_idx in &entity_backing.data {
        if entity_idx >= entity_backing.len {
          break
        }
        {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}temp_{{result_name}}{{/results}} := {{/has_results}}entity_{{message_name}}_ptr(&{{safe_entity_name}}{{#params}}, {{param_name}}{{/params}})
        {{#results}}
          {{result_name}} |= temp_{{result_name}}
        {{/results}}
      }
      return
    }

    entity_{{message_name}}_at :: proc({{safe_tile_pos_name}} : TilePos{{#params}}, {{param_decl}}{{/params}}){{#has_results}} -> ({{#results}}{{#not_first}}, {{/not_first}}{{result_decl}}{{/results}}){{/has_results}} {
      {{safe_entity_name}} := entity_sas[{{safe_tile_pos_name}}]
      for {{safe_entity_name}} != nil {
        {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}temp_{{result_name}}{{/results}} := {{/has_results}}entity_{{message_name}}_ptr({{safe_entity_name}}{{#params}}, {{param_name}}{{/params}})
        {{#results}}
          {{result_name}} |= temp_{{result_name}}
        {{/results}}
        {{safe_entity_name}} = get_base({{safe_entity_name}}).next_entity_at_pos
      }
      return
    }
{{/messages}}
`
