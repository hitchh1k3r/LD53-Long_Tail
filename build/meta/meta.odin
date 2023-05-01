package meta

import "core:fmt"
import "core:mem"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:os/os2"
import "core:reflect"
import "core:slice"
import "core:strings"

parse_game :: proc() -> (root_declarations : map[string]MetaDecl, all_files_ast : map[string]^ast.File) {
  PROFILE_START("parse_game()")
  if pack, ok := parser.parse_package_from_path("src/game"); ok {
    PROFILE_END()
    PROFILE("process_game()")
    for _, file in pack.derived.(^ast.Package).files {
      if !strings.has_suffix(file.fullpath, "_.odin") {
        GAME_PKG_PATH :: []u8{ 's', 'r', 'c', os2.Path_Separator, 'g', 'a', 'm', 'e', os2.Path_Separator }
        all_files_ast[file.fullpath[strings.last_index(file.fullpath, transmute(string)(GAME_PKG_PATH))+len(GAME_PKG_PATH):]] = file
        for d in file.decls {
          if decl, ok := d.derived.(^ast.Value_Decl); ok {
            new_decl : MetaDecl
            new_decl.file = file

            max_attributes := 0
            for att in decl.attributes {
              for _ in att.derived.(^ast.Attribute).elems {
                max_attributes += 1
              }
            }
            new_decl.attrs = make([]MetaAttribute, max_attributes)

            attribute_idx := 0
            for att, att_idx in decl.attributes {
              for el, el_idx in att.derived.(^ast.Attribute).elems {
                #partial switch n in el.derived {
                  case (^ast.Ident):
                    new_decl.attrs[attribute_idx] = { { n.name, n.pos.line, n.pos.column }, {} }
                    attribute_idx += 1
                  case (^ast.Field_Value):
                    line, col := ast_get_line_col(n.value.derived)
                    start, end := ast_get_start_end(n.value.derived)
                    new_decl.attrs[attribute_idx] = { { n.field.derived.(^ast.Ident).name, n.field.pos.line, n.field.pos.column }, { file.src[start:end], line, col } }
                    attribute_idx += 1
                  case:
                    panic("MetaBug: unknown attribute AST")
                }
              }
            }
            new_decl.attrs = new_decl.attrs[:attribute_idx]
            new_decl.is_const = !decl.is_mutable

            if decl.type != nil {
              new_decl.type = ast_to_meta_type(decl.type.derived)
            }
            for name, idx in decl.names {
              new_decl.line_num = name.pos.line
              new_decl.col_num = name.pos.column
              if decl.type == nil && idx < len(decl.values) {
                new_decl.value = decl.values[idx].derived
              }
              root_declarations[name.derived.(^ast.Ident).name] = new_decl
            }
          }
        }
      }
    }
  } else {
    PROFILE_END()
    fmt.eprintln("Could not parse src/game package!")
    os.exit(1)
  }
  return
}

// Utils ///////////////////////////////////////////////////////////////////////////////////////////

  MetaType :: union {
    string,
    ^ast.Typeid_Type,
    ^ast.Helper_Type,
    ^ast.Poly_Type,
    ^ast.Proc_Type,
    ^ast.Pointer_Type,
    ^ast.Multi_Pointer_Type,
    ^ast.Array_Type,
    ^ast.Dynamic_Array_Type,
    ^ast.Struct_Type,
    ^ast.Union_Type,
    ^ast.Enum_Type,
    ^ast.Bit_Set_Type,
    ^ast.Map_Type,
    ^ast.Relative_Type,
    ^ast.Matrix_Type,
    ^ast.Selector_Expr,
    ^ast.Call_Expr, // for parapoly
  }

  MetaAttribute :: struct {
    key, value : MetaText,
  }

  MetaText :: struct {
    text : string,
    line_num, col_num : int,
  }

  MetaDecl :: struct {
    attrs : []MetaAttribute,
    type : MetaType,
    value : ast.Any_Node,
    file : ^ast.File,
    line_num, col_num : int,
    is_const : bool,
  }

  MetaField :: struct {
    field : ^ast.Field,
    name : string,
    is_const : bool,
    type : string,
    default : string,
  }

  MetaProc :: struct {
    params : [dynamic]MetaField,
    results : [dynamic]MetaField,
  }

  find_meta_attribute :: proc(attributes : []MetaAttribute, name : string) -> MetaAttribute {
    PROFILE(#procedure, name)
    for att in attributes {
      if att.key.text == name {
        return att
      }
    }
    return {}
  }

  ast_field_to_meta_field :: proc(field : ^ast.Field, file : ^ast.File) -> (result : MetaField) {
    PROFILE(#procedure)
    result.field = field
    if field.type != nil {
      if _, ok := field.type.derived.(^ast.Typeid_Type); ok {
        result.type = "typeid"
      } else {
        result.type = file.src[field.type.pos.offset:field.type.end.offset]
      }
    }
    if field.default_value != nil {
      result.default = file.src[field.default_value.pos.offset:field.default_value.end.offset]
    }
    return
  }

  ast_to_meta_type :: proc(node : ast.Any_Node, loc := #caller_location) -> MetaType {
    #partial switch type in node {
      case ^ast.Ident:
        return type.name
      case ^ast.Typeid_Type:
        return type
      case ^ast.Helper_Type:
        return type
      case ^ast.Distinct_Type:
        return ast_to_meta_type(type.type.derived)
      case ^ast.Poly_Type:
        return type
      case ^ast.Proc_Type:
        return type
      case ^ast.Pointer_Type:
        return type
      case ^ast.Multi_Pointer_Type:
        return type
      case ^ast.Array_Type:
        return type
      case ^ast.Dynamic_Array_Type:
        return type
      case ^ast.Struct_Type:
        return type
      case ^ast.Union_Type:
        return type
      case ^ast.Enum_Type:
        return type
      case ^ast.Bit_Set_Type:
        return type
      case ^ast.Map_Type:
        return type
      case ^ast.Relative_Type:
        return type
      case ^ast.Matrix_Type:
        return type
      case ^ast.Selector_Expr:
        return type
      case ^ast.Call_Expr:
        return type
      case:
        panic(fmt.tprintf("unsupported type %v", reflect.union_variant_typeid(node)), loc)
    }
    return {}
  }

  ast_get_line_col :: proc(node : ast.Any_Node) -> (line, col : int) {
    switch node in node {
      case ^ast.Package:
        return node.pos.line, node.pos.column
      case ^ast.File:
        return node.pos.line, node.pos.column
      case ^ast.Comment_Group:
        return node.pos.line, node.pos.column
      case ^ast.Bad_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Ident:
        return node.pos.line, node.pos.column
      case ^ast.Implicit:
        return node.pos.line, node.pos.column
      case ^ast.Undef:
        return node.pos.line, node.pos.column
      case ^ast.Basic_Lit:
        return node.pos.line, node.pos.column
      case ^ast.Basic_Directive:
        return node.pos.line, node.pos.column
      case ^ast.Ellipsis:
        return node.pos.line, node.pos.column
      case ^ast.Proc_Lit:
        return node.pos.line, node.pos.column
      case ^ast.Comp_Lit:
        return node.pos.line, node.pos.column
      case ^ast.Tag_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Unary_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Binary_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Paren_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Selector_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Implicit_Selector_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Selector_Call_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Index_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Deref_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Slice_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Matrix_Index_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Call_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Field_Value:
        return node.pos.line, node.pos.column
      case ^ast.Ternary_If_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Ternary_When_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Or_Else_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Or_Return_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Type_Assertion:
        return node.pos.line, node.pos.column
      case ^ast.Type_Cast:
        return node.pos.line, node.pos.column
      case ^ast.Auto_Cast:
        return node.pos.line, node.pos.column
      case ^ast.Inline_Asm_Expr:
        return node.pos.line, node.pos.column
      case ^ast.Proc_Group:
        return node.pos.line, node.pos.column
      case ^ast.Typeid_Type:
        return node.pos.line, node.pos.column
      case ^ast.Helper_Type:
        return node.pos.line, node.pos.column
      case ^ast.Distinct_Type:
        return node.pos.line, node.pos.column
      case ^ast.Poly_Type:
        return node.pos.line, node.pos.column
      case ^ast.Proc_Type:
        return node.pos.line, node.pos.column
      case ^ast.Pointer_Type:
        return node.pos.line, node.pos.column
      case ^ast.Multi_Pointer_Type:
        return node.pos.line, node.pos.column
      case ^ast.Array_Type:
        return node.pos.line, node.pos.column
      case ^ast.Dynamic_Array_Type:
        return node.pos.line, node.pos.column
      case ^ast.Struct_Type:
        return node.pos.line, node.pos.column
      case ^ast.Union_Type:
        return node.pos.line, node.pos.column
      case ^ast.Enum_Type:
        return node.pos.line, node.pos.column
      case ^ast.Bit_Set_Type:
        return node.pos.line, node.pos.column
      case ^ast.Map_Type:
        return node.pos.line, node.pos.column
      case ^ast.Relative_Type:
        return node.pos.line, node.pos.column
      case ^ast.Matrix_Type:
        return node.pos.line, node.pos.column
      case ^ast.Bad_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Empty_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Expr_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Tag_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Assign_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Block_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.If_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.When_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Return_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Defer_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.For_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Range_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Inline_Range_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Case_Clause:
        return node.pos.line, node.pos.column
      case ^ast.Switch_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Type_Switch_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Branch_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Using_Stmt:
        return node.pos.line, node.pos.column
      case ^ast.Bad_Decl:
        return node.pos.line, node.pos.column
      case ^ast.Value_Decl:
        return node.pos.line, node.pos.column
      case ^ast.Package_Decl:
        return node.pos.line, node.pos.column
      case ^ast.Import_Decl:
        return node.pos.line, node.pos.column
      case ^ast.Foreign_Block_Decl:
        return node.pos.line, node.pos.column
      case ^ast.Foreign_Import_Decl:
        return node.pos.line, node.pos.column
      case ^ast.Attribute:
        return node.pos.line, node.pos.column
      case ^ast.Field:
        return node.pos.line, node.pos.column
      case ^ast.Field_List:
        return node.pos.line, node.pos.column
    }
    return 0, 0
  }

  ast_get_start_end :: proc(node : ast.Any_Node) -> (strat, end : int) {
    switch node in node {
      case ^ast.Package:
        return node.pos.offset, node.end.offset
      case ^ast.File:
        return node.pos.offset, node.end.offset
      case ^ast.Comment_Group:
        return node.pos.offset, node.end.offset
      case ^ast.Bad_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Ident:
        return node.pos.offset, node.end.offset
      case ^ast.Implicit:
        return node.pos.offset, node.end.offset
      case ^ast.Undef:
        return node.pos.offset, node.end.offset
      case ^ast.Basic_Lit:
        return node.pos.offset, node.end.offset
      case ^ast.Basic_Directive:
        return node.pos.offset, node.end.offset
      case ^ast.Ellipsis:
        return node.pos.offset, node.end.offset
      case ^ast.Proc_Lit:
        return node.pos.offset, node.end.offset
      case ^ast.Comp_Lit:
        return node.pos.offset, node.end.offset
      case ^ast.Tag_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Unary_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Binary_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Paren_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Selector_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Implicit_Selector_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Selector_Call_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Index_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Deref_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Slice_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Matrix_Index_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Call_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Field_Value:
        return node.pos.offset, node.end.offset
      case ^ast.Ternary_If_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Ternary_When_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Or_Else_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Or_Return_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Type_Assertion:
        return node.pos.offset, node.end.offset
      case ^ast.Type_Cast:
        return node.pos.offset, node.end.offset
      case ^ast.Auto_Cast:
        return node.pos.offset, node.end.offset
      case ^ast.Inline_Asm_Expr:
        return node.pos.offset, node.end.offset
      case ^ast.Proc_Group:
        return node.pos.offset, node.end.offset
      case ^ast.Typeid_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Helper_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Distinct_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Poly_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Proc_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Pointer_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Multi_Pointer_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Array_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Dynamic_Array_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Struct_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Union_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Enum_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Bit_Set_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Map_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Relative_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Matrix_Type:
        return node.pos.offset, node.end.offset
      case ^ast.Bad_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Empty_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Expr_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Tag_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Assign_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Block_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.If_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.When_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Return_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Defer_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.For_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Range_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Inline_Range_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Case_Clause:
        return node.pos.offset, node.end.offset
      case ^ast.Switch_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Type_Switch_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Branch_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Using_Stmt:
        return node.pos.offset, node.end.offset
      case ^ast.Bad_Decl:
        return node.pos.offset, node.end.offset
      case ^ast.Value_Decl:
        return node.pos.offset, node.end.offset
      case ^ast.Package_Decl:
        return node.pos.offset, node.end.offset
      case ^ast.Import_Decl:
        return node.pos.offset, node.end.offset
      case ^ast.Foreign_Block_Decl:
        return node.pos.offset, node.end.offset
      case ^ast.Foreign_Import_Decl:
        return node.pos.offset, node.end.offset
      case ^ast.Attribute:
        return node.pos.offset, node.end.offset
      case ^ast.Field:
        return node.pos.offset, node.end.offset
      case ^ast.Field_List:
        return node.pos.offset, node.end.offset
    }
    return 0, 0
  }

  // TODO (hitch) 2023-04-29 This is broken, the names can be from different files, but we are
  //       searching the wrong src!!!
  /*
  ast_search_for_name :: proc(name : string, names : []^ast.Expr, src : string) -> ^ast.Expr {
    PROFILE(#procedure, name)
    for n in names {
      if src[n.pos.offset] == '$' {
        if name == src[n.pos.offset+1:n.end.offset] {
          return n
        }
      } else {
        if name == src[n.pos.offset:n.end.offset] {
          return n
        }
      }
    }
    return nil
  }
  */

  ast_to_meta_proc :: proc(proc_type : ^ast.Proc_Type, file : ^ast.File) -> (result : MetaProc) {
    PROFILE(#procedure)
    if proc_type.params != nil {
      for proc_param in proc_type.params.list {
        meta_field := ast_field_to_meta_field(proc_param, file)
        if len(proc_param.names) > 0 {
          for name_node in proc_param.names {
            name := file.src[name_node.pos.offset:name_node.end.offset]
            if name[0] == '$' {
              name = name[1:]
              meta_field.name = name
              meta_field.is_const = true
              append(&result.params, meta_field)
              meta_field.is_const = false
            } else {
              meta_field.name = name
              append(&result.params, meta_field)
            }
          }
        } else {
          meta_field.name = ""
          append(&result.params, meta_field)
        }
      }
    }
    if proc_type.results != nil {
      for proc_result in proc_type.results.list {
        meta_field := ast_field_to_meta_field(proc_result, file)
        if len(proc_result.names) > 0 {
          for name_node in proc_result.names {
            if id, ok := name_node.derived.(^ast.Ident); ok {
              meta_field.name = id.name
              append(&result.results, meta_field)
            } else {
              name := file.src[name_node.pos.offset:name_node.end.offset]
              meta_field.name = name
              append(&result.results, meta_field)
            }
          }
        } else {
          meta_field.name = ""
          append(&result.results, meta_field)
        }
      }
    }
    return
  }

  ast_resolve_constant :: proc(node : ast.Any_Node, declarations : map[string]MetaDecl) -> (resolved : ast.Any_Node, ok : bool) {
    PROFILE(#procedure)
    node := node
    for _ in 0..<50 {
      if id, ok := node.(^ast.Ident); ok {
        if decl, ok := declarations[id.name]; ok {
          if decl.is_const {
            node = decl.value
            continue
          }
        }
      }
      return node, true
    }
    return {}, false
  }

  ast_is_field_ellipsis :: proc(field : ^ast.Field) -> bool {
    _, ok := field.type.derived.(^ast.Ellipsis)
    return ok || .Ellipsis in field.flags
  }

  field_to_declaration_string :: proc(field : MetaField, allocator := context.allocator) -> string {
    PROFILE(#procedure)
    bld := strings.builder_make(allocator)
    if field.default == "" {
      if .No_Alias in field.field.flags {
        strings.write_string(&bld, "#no_alias ")
      }
      if .C_Vararg in field.field.flags {
        strings.write_string(&bld, "#c_vararg ")
      }
      if .Any_Int in field.field.flags {
        strings.write_string(&bld, "#any_int ")
      }
      if .Subtype in field.field.flags {
        strings.write_string(&bld, "#subtype ")
      }
      if .By_Ptr in field.field.flags {
        strings.write_string(&bld, "#by_ptr ")
      }
      if field.name != "" {
        if field.is_const {
          strings.write_byte(&bld, '$')
        }
        strings.write_string(&bld, field.name)
        strings.write_string(&bld, " : ")
      }
      if ast_is_field_ellipsis(field.field) {
        strings.write_string(&bld, "..")
      }
      strings.write_string(&bld, field.type)
    } else {
      if .No_Alias in field.field.flags {
        strings.write_string(&bld, "#no_alias ")
      }
      if .C_Vararg in field.field.flags {
        strings.write_string(&bld, "#c_vararg ")
      }
      if .Any_Int in field.field.flags {
        strings.write_string(&bld, "#any_int ")
      }
      if .Subtype in field.field.flags {
        strings.write_string(&bld, "#subtype ")
      }
      if .By_Ptr in field.field.flags {
        strings.write_string(&bld, "#by_ptr ")
      }
      if field.is_const {
        strings.write_byte(&bld, '$')
      }
      if field.type != "" {
        strings.write_string(&bld, field.name)
        strings.write_string(&bld, " : ")
        if ast_is_field_ellipsis(field.field) {
          strings.write_string(&bld, "..")
        }
        strings.write_string(&bld, field.type)
        strings.write_string(&bld, " = ")
        strings.write_string(&bld, field.default)
      } else {
        strings.write_string(&bld, field.name)
        strings.write_string(&bld, " := ")
        strings.write_string(&bld, field.default)
      }
    }
    return strings.to_string(bld)
  }

  sort_params :: proc(params : []MetaField, allocator := context.allocator) -> []MetaField {
    result := slice.clone(params, allocator)
    slice.sort_by(result, proc(l, r : MetaField) -> bool {
      if ast_is_field_ellipsis(r.field) {
        return true
      } else if ast_is_field_ellipsis(l.field) {
        return false
      }
      return l.name < r.name
    })
    return result
  }
