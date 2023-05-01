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

default_allocator : mem.Allocator
message_prototypes : map[string]map[string]meta.MetaProc

gen_world :: proc() {
  PROFILE(#procedure)
  data := make([]u8, 2 * mem.Gigabyte)
  defer delete(data)
  arena : mem.Arena
  mem.arena_init(&arena, data)
  arena_allocator := mem.arena_allocator(&arena)
  {
    context.allocator = arena_allocator

    // Write Tiles File:
      beard_messages := make(beard.Slice, len(message_prototypes))
      message_idx : int
      for message_name, message_procs in message_prototypes {
        defer message_idx += 1

        unique_fields : [dynamic]string = { "tile_pos" }
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
        for proc_domain, proc_data in message_procs {
          if proc_domain == "" {
            continue
          }
          defer proc_idx += 1

          beard_params := make(beard.Slice, len(proc_data.params))
          proc_params := meta.sort_params(proc_data.params[:])
          defer delete(proc_params)
          for param, param_idx in proc_params {
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
            "proc_domain" = proc_domain,
            "params" = beard_params,
            "has_results" = (len(beard_results) > 0),
            "results" = beard_results,
          }
        }

        beard_messages[message_idx] = beard.Map{
          "message_name" = message_name,
          "message_slashes" = slashes[19+len(message_name):],
          "safe_tile_pos_name" = "tile_pos",
          "params" = beard_proto_params,
          "has_results" = (len(beard_proto_results) > 0),
          "results" = beard_proto_results,
          "procs" = beard_procs,
        }
      }

      world_data : beard.Node = beard.Map{
        "messages" = beard_messages,
      }

      world_src := beard.process(TEMPLATE_TILE_FILE, world_data)
      if !os.write_entire_file("./src/game/world_.odin", transmute([]u8)(world_src)) {
        fmt.eprintln("Could not write world_.odin")
        os.exit(1)
      }
  }
}

// messages[
//   message_name"
//   message_slashes"
//   safe_tile_pos_name"
//   params[
//     param_name"
//     param_decl"
//     not_first?
//   has_results?
//   results[
//     param_name"
//     param_decl"
//     not_first?
//   procs[
//     proc_domain"
//     params[
//       param_name"
//       param_decl"
//       not_first?
//     has_results?
//     results[
//       param_name"
//       param_decl"
//       not_first?

@(private="file")
TEMPLATE_TILE_FILE :: `package game

import "project:graphics"

////////////////////////////////////////////////////////////////////////////////////////////////////
///// This file is automatically generated, do not edit it by hand or changes will be erased!  /////
////////////////////////////////////////////////////////////////////////////////////////////////////
{{#messages}}

  // World Message "{{message_name}}" /{{message_slashes}}

    world_{{message_name}} :: proc{ world_{{message_name}}_at }

    world_{{message_name}}_at :: proc({{safe_tile_pos_name}} : TilePos{{#params}}, {{param_decl}}{{/params}}){{#has_results}} -> ({{#results}}{{#not_first}}, {{/not_first}}{{result_decl}}{{/results}}){{/has_results}} {
      {{#results}}
        temp_{{result_decl}}
      {{/results}}

      {{#procs}}
        {{#has_results}}{{#results}}{{#not_first}}, {{/not_first}}temp_{{result_name}}{{/results}} = {{/has_results}}{{proc_domain}}_{{message_name}}_at({{safe_tile_pos_name}}{{#params}}, {{param_name}}{{/params}})
        {{#results}}
          {{result_name}} |= temp_{{result_name}}
        {{/results}}

      {{/procs}}
      return
    }
{{/messages}}
`

init_world :: proc() {
  PROFILE(#procedure)
  default_allocator = context.allocator
  message_prototypes = make_map(map[string]map[string]meta.MetaProc, 1024, context.allocator)
}

add_params :: proc(new_proc : meta.MetaProc, proto : ^meta.MetaProc, param_start_idx : int, file : ^ast.File, message_domain, message_name : string) -> (has_error : bool) {
  PROFILE(#procedure)
  if message_name not_in message_prototypes {
    message_prototypes[message_name] = make_map(map[string]meta.MetaProc, 1024, default_allocator)
  }
  if "" not_in message_prototypes[message_name] {
    (&message_prototypes[message_name])[""] = {}
    temp := &(&message_prototypes[message_name])[""]
    temp.params = make([dynamic]meta.MetaField, default_allocator)
    temp.results = make([dynamic]meta.MetaField, default_allocator)
  }
  if message_domain not_in message_prototypes[message_name] {
    (&message_prototypes[message_name])[message_domain] = {}
    temp := &(&message_prototypes[message_name])[message_domain]
    temp.params = make([dynamic]meta.MetaField, default_allocator)
    temp.results = make([dynamic]meta.MetaField, default_allocator)
  }

  has_error |= _add_params(new_proc, proto, param_start_idx, file, message_domain, message_name)
  has_error |= _add_params(new_proc, &message_prototypes[message_name][""], param_start_idx, file, message_domain, message_name)
  has_error |= _add_params(new_proc, &message_prototypes[message_name][message_domain], param_start_idx, file, message_domain, message_name)
  return
}

_add_params :: proc(new_proc : meta.MetaProc, proto : ^meta.MetaProc, param_start_idx : int, file : ^ast.File, message_domain, message_name : string) -> (has_error : bool) {
  PROFILE(#procedure)
  outer_loop: for new_param in new_proc.params[param_start_idx:] {
    for old_param in proto.params {
      if old_param.name == new_param.name {
        new_field := new_param.field
        old_field := old_param.field
        /*
        new_field := meta.ast_search_for_name(new_param.name, new_param.field.names, file.src)
        old_field := meta.ast_search_for_name(old_param.name, old_param.field.names, file.src)
        if new_field == nil {
          new_field = new_param.field.type
        }
        if new_field == nil {
          new_field = new_param.field.names[0]
        }
        if old_field == nil {
          old_field = old_param.field.type
        }
        if old_field == nil {
          old_field = old_param.field.names[0]
        }
        */
        previous_decl : ^ast.Field

        if old_param.type != new_param.type {
          fmt.eprintf("%v(%v:%v) Meta Error: %v message '%v' parameter '%v' of type '%v' was previously declared as '%v'\n", file.fullpath, new_field.pos.line, new_field.pos.column, message_domain, message_name, new_param.name, new_param.type, old_param.type)
          if previous_decl != nil && previous_decl != new_param.field {
            fmt.eprintf("%v(%v:%v)   ----> previously declaration\n", file.fullpath, old_field.pos.line, old_field.pos.column)
          }
          previous_decl = new_param.field
          has_error = true
        }
        if old_param.is_const != new_param.is_const {
          if new_param.is_const {
            fmt.eprintf("%v(%v:%v) Meta Error: %v message '%v' constant parameter '%v' was previously declared as not constant\n", file.fullpath, new_field.pos.line, new_field.pos.column, message_domain, message_name, new_param.name)
          } else {
            fmt.eprintf("%v(%v:%v) Meta Error: %v message '%v' not constant parameter '%v' was previously declared as constant\n", file.fullpath, new_field.pos.line, new_field.pos.column, message_domain, message_name, new_param.name)
          }
          if previous_decl != nil && previous_decl != new_param.field {
            fmt.eprintf("%v(%v:%v)   ----> previously declaration\n", file.fullpath, old_field.pos.line, old_field.pos.column)
          }
          previous_decl = new_param.field
          has_error = true
        }
        if old_param.default != new_param.default {
          fmt.eprintf("%v(%v:%v) Meta Error: %v message '%v' parameter '%v' with default value of '%v' was previously declared with default value of '%v'\n", file.fullpath, new_field.pos.line, new_field.pos.column, message_domain, message_name, new_param.name, new_param.default, old_param.default)
          if previous_decl != nil && previous_decl != new_param.field {
            fmt.eprintf("%v(%v:%v)   ----> previously declaration\n", file.fullpath, old_field.pos.line, old_field.pos.column)
          }
          previous_decl = new_param.field
          has_error = true
        }
        TEST_MASK :: ast.Field_Flags{ .Ellipsis, .No_Alias, .C_Vararg, .Any_Int, .Subtype, .By_Ptr }
        if (old_param.field.flags & TEST_MASK) != (new_param.field.flags & TEST_MASK) {
          fmt.eprintf("%v(%v:%v) Meta Error: %v message '%v' parameter '%v' with flags '%v' was previously declared with flags '%v'\n", file.fullpath, new_field.pos.line, new_field.pos.column, message_domain, message_name, new_param.name, (new_param.field.flags & TEST_MASK), (old_param.field.flags & TEST_MASK))
          if previous_decl != nil && previous_decl != new_param.field {
            fmt.eprintf("%v(%v:%v)   ----> previously declaration\n", file.fullpath, old_field.pos.line, old_field.pos.column)
          }
          previous_decl = new_param.field
          has_error = true
        }
        if previous_decl != nil {
          fmt.eprintf("%v(%v:%v)   ----> previously declaration\n", file.fullpath, old_field.pos.line, old_field.pos.column)
        }
        continue outer_loop
      }
    }
    append(&proto.params, new_param)
  }
  return
}

add_results :: proc(new_proc : meta.MetaProc, proto : ^meta.MetaProc, file : ^ast.File, message_domain, message_name : string) -> (has_error : bool) {
  PROFILE(#procedure)
  if message_name not_in message_prototypes {
    message_prototypes[message_name] = make_map(map[string]meta.MetaProc, 1024, default_allocator)
  }
  if "" not_in message_prototypes[message_name] {
    (&message_prototypes[message_name])[""] = {}
    temp := &(&message_prototypes[message_name])[""]
    temp.params = make([dynamic]meta.MetaField, default_allocator)
    temp.results = make([dynamic]meta.MetaField, default_allocator)
  }
  if message_domain not_in message_prototypes[message_name] {
    (&message_prototypes[message_name])[message_domain] = {}
    temp := &(&message_prototypes[message_name])[message_domain]
    temp.params = make([dynamic]meta.MetaField, default_allocator)
    temp.results = make([dynamic]meta.MetaField, default_allocator)
  }

  has_error |= _add_results(new_proc, proto, file, message_domain, message_name)
  has_error |= _add_results(new_proc, &message_prototypes[message_name][""], file, message_domain, message_name)
  has_error |= _add_results(new_proc, &message_prototypes[message_name][message_domain], file, message_domain, message_name)
  return
}

_add_results :: proc(new_proc : meta.MetaProc, proto : ^meta.MetaProc, file : ^ast.File, message_domain, message_name : string) -> (has_error : bool) {
  PROFILE(#procedure)
  outer_loop: for new_result in new_proc.results {
    for old_result in proto.results {
      if old_result.name == new_result.name {
        if old_result.type != new_result.type {
          new_field := new_result.field
          old_field := old_result.field
          /*
          new_field := meta.ast_search_for_name(new_result.name, new_result.field.names, file.src)
          old_field := meta.ast_search_for_name(old_result.name, old_result.field.names, file.src)
          if new_field == nil {
            new_field = new_result.field.type
          }
          if new_field == nil {
            new_field = new_result.field.names[0]
          }
          if old_field == nil {
            old_field = old_result.field.type
          }
          if old_field == nil {
            old_field = old_result.field.names[0]
          }
          */
          fmt.eprintf("%v(%v:%v) Meta Error: %v message '%v' result '%v' of type '%v' was previously declared as '%v'\n", file.fullpath, new_field.pos.line, new_field.pos.column, message_domain, message_name, new_result.name, new_result.type, old_result.type)
          fmt.eprintf("%v(%v:%v)   ----> previously declaration\n", file.fullpath, old_field.pos.line, old_field.pos.column)
          has_error = true
        }
        continue outer_loop
      }
    }
    append(&proto.results, new_result)
  }
  return
}
