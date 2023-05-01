package project_errors

import "core:fmt"
import "core:odin/ast"
import "core:os"
import "core:reflect"
import "core:slice"

import "build:meta"

check_for_errors :: proc(all_files_ast : map[string]^ast.File) {
  PROFILE(#procedure)

  for filename, file_ast in all_files_ast {
    if filename == "entities.odin" {
      add_stack := make([dynamic]string)
      has_err := false
      ast.walk(&ast.Visitor{ visit_node, &VisitorState{ file_ast, &add_stack, make([dynamic]string), &has_err } }, &file_ast.node)
      delete(add_stack)
      if has_err {
        os.exit(1)
      }
    }
  }
}

VisitorState :: struct {
  file : ^ast.File,
  add_stack : ^[dynamic]string,
  allowed_mutations : [dynamic]string,
  has_err : ^bool,
}

visit_node :: proc(visitor : ^ast.Visitor, node : ^ast.Node) -> ^ast.Visitor {
  using state := (^VisitorState)(visitor.data)

  if node == nil {
    delete(allowed_mutations)
    free(state)
    free(visitor)
    return nil
  }

  if _, ok := node.derived.(^ast.Block_Stmt); ok {
    if len(add_stack) > 0 {
      append(array = &allowed_mutations, args = add_stack[:])
      clear(add_stack)
    }
  }

  if attr, ok := node.derived.(^ast.Attribute); ok {
    for elm in attr.elems {
      if field, ok := elm.derived.(^ast.Field_Value); ok {
        if field.field.derived.(^ast.Ident).name == "allow_mutation" {
          start, end := meta.ast_get_start_end(field.value.derived)
          append(add_stack, file.src[start:end])
          return clone_visitor(visitor)
        }
      }
    }
  }

  if assign, ok := node.derived.(^ast.Assign_Stmt); ok {
    for lhs in assign.lhs {
      if selector, ok := lhs.derived.(^ast.Selector_Expr); ok {
        if selector.field.name[0] == '_' {
          if !slice.contains(allowed_mutations[:], selector.field.name) {
            fmt.eprintf("%v(%v:%v) Error: '%v' can not be mutated without the allow_mutation attribute\n", file.fullpath, selector.field.pos.line, selector.field.pos.column, selector.field.name)
            has_err^ = true
          }
        }
      }
    }
  }

  return clone_visitor(visitor)
}

clone_visitor :: proc(visitor : ^ast.Visitor) -> ^ast.Visitor {
  using state := (^VisitorState)(visitor.data)

  new_state := new(VisitorState)
  new_state.file = file
  new_state.add_stack = add_stack
  new_state.allowed_mutations = slice.clone_to_dynamic(allowed_mutations[:])
  new_state.has_err = has_err

  new_visitor := new(ast.Visitor)
  new_visitor.visit = visit_node
  new_visitor.data = new_state

  return new_visitor
}