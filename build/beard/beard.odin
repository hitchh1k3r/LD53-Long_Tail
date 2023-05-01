package yeard

import "core:fmt"
import "core:strings"

Slice :: []Node
Map :: map[string]Node

Node :: union {
  string,
  bool,
  Slice,
  Map,
}

pretty_print :: proc(node : Node, indent := 0) {
  PROFILE(#procedure)
  switch node in node {
    case string:
      fmt.printf("\"%v\"", node)
    case bool:
      fmt.printf("%v", node)
    case Slice:
      fmt.print("Slice{\n")
      for el in node {
        indent := indent+1
        for _ in 0..<indent {
          fmt.print("  ")
        }
        pretty_print(el, indent)
        fmt.print(",\n")
      }
      for _ in 0..<indent {
        fmt.print("  ")
      }
      fmt.print("}")
    case Map:
      fmt.print("Map{\n")
      for map_key in node {
        indent := indent+1
        for _ in 0..<indent {
          fmt.print("  ")
        }
        fmt.printf("\"%v\" = ", map_key)
        pretty_print(node[map_key], indent)
        fmt.print(",\n")
      }
      for _ in 0..<indent {
        fmt.print("  ")
      }
      fmt.print("}")
  }
  if indent == 0 {
    fmt.print("\n")
  }
}

process :: proc(template : string, node : Node, allocator := context.allocator) -> string {
  PROFILE(#procedure)
  // Tokenize:
    tokenized_template : [dynamic]TemplateToken
    TemplateToken :: struct {
      type : enum { Literal, Open, Close, Variable, Line_Break },
      content : string,
    }
    {
      template := template
      for {
        if tag_open := strings.index(template, "{{"); tag_open >= 0 {
          if tag_close := strings.index(template[tag_open:], "}}"); tag_close >= 0 {
            if tag_open > 0 {
              tag_open := tag_open
              template := template
              for {
                line_idx := strings.index_byte(template, '\n')
                if line_idx >= 0 {
                  if line_idx < tag_open {
                    if line_idx > 0 {
                      append(&tokenized_template, TemplateToken{ .Literal, template[:line_idx] })
                    }
                    append(&tokenized_template, TemplateToken{ .Line_Break, "" })
                    template = template[line_idx+1:]
                    tag_open -= line_idx+1
                  } else {
                    append(&tokenized_template, TemplateToken{ .Literal, template[:tag_open] })
                    break
                  }
                } else {
                  append(&tokenized_template, TemplateToken{ .Literal, template })
                  break
                }
              }
            }
            tag_close += tag_open
            tag := template[tag_open+2:tag_close]
            if tag[0] == '#' {
              append(&tokenized_template, TemplateToken{ .Open, template[tag_open:tag_close+2] })
            } else if tag[0] == '/' {
              append(&tokenized_template, TemplateToken{ .Close, template[tag_open:tag_close+2] })
            } else {
              append(&tokenized_template, TemplateToken{ .Variable, tag })
            }
            template = template[tag_close+2:]
            continue
          }
        }
        break
      }
      append(&tokenized_template, TemplateToken{ .Literal, template })
    }

    // validate open/close tags (turn others into literals)
    validate :: proc(template : []TemplateToken) {
      PROFILE(#procedure)
      template := template
      for len(template) > 0 {
        token := template[0]
        switch token.type {
          case .Literal:
          case .Line_Break:
          case .Variable:
          case .Open:
            depth := 0
            end := 0
            for t, idx in template {
              if t.type == .Open {
                if t.content[3:len(t.content)-2] == token.content[3:len(token.content)-2] {
                  depth += 1
                }
              }
              if t.type == .Close {
                if t.content[3:len(t.content)-2] == token.content[3:len(token.content)-2] {
                  depth -= 1
                  if depth <= 0 {
                    end = idx
                    break
                  }
                }
              }
            }
            if end > 0 {
              validate(template[1:end-1])
              template[0].content = template[0].content[3:len(template[0].content)-2]
              template[end].content = template[end].content[3:len(template[end].content)-2]
              template = template[end:]
            } else {
              template[0].type = .Literal
            }
          case .Close:
            template[0].type = .Literal
        }
        template = template[1:]
      }
    }
    validate(tokenized_template[:])


  NodeStack :: struct {
    stack : [32]Map,
    idx : int,
  }

  find_in_stack :: proc(stack : NodeStack, key : string) -> (node : Node, ok : bool) {
    PROFILE(#procedure, key)
    for i := stack.idx-1; i >= 0; i -= 1 {
      if child, ok := stack.stack[i][key]; ok {
        return child, true
      }
    }
    return
  }

  parse :: proc(template : []TemplateToken, output : ^strings.Builder, stack : NodeStack, indent : int = 0) {
    PROFILE(#procedure)
    template := template
    fresh_line := false
    eat_line := (indent > 0)
    for len(template) > 0 {
      token := template[0]
      defer template = template[1:]
      next_eat_new_line := false
      defer eat_line = next_eat_new_line
      switch token.type {
        case .Literal:
          literal := token.content
          trimed_literal := strings.trim_left_space(literal)
          if len(trimed_literal) == 0 {
            line := template[1:]
            for t, i in line {
              if t.type == .Line_Break {
                if i > 0 {
                  line = line[:i-1]
                } else {
                  line = {}
                }
                break
              }
            }
            empty_line := true
            for t in line {
              if t.type == .Literal {
                if len(strings.trim_left_space(t.content)) > 0 {
                  empty_line = false
                  break
                }
              } else if t.type == .Variable {
                empty_line = false
                break
              }
            }
            if empty_line {
              continue
            }
          }
          if fresh_line {
            fresh_line = false
            trim := min(2*indent, len(literal)-len(trimed_literal))
            literal = literal[trim:]
          }
          strings.write_string(output, literal)
        case .Line_Break:
          if !eat_line {
            strings.write_byte(output, '\n')
          }
          fresh_line = true
        case .Variable:
          fresh_line = false
          if child, ok := find_in_stack(stack, token.content); ok {
            if str, ok := child.(string); ok {
              strings.write_string(output, str)
            }
          }
        case .Open:
          depth := 0
          end := 0
          for t, idx in template {
            if t.type == .Open {
              if t.content == token.content {
                depth += 1
              }
            }
            if t.type == .Close {
              if t.content == token.content {
                depth -= 1
                if depth <= 0 {
                  end = idx
                  break
                }
              }
            }
          }
          if end > 0 {
            if child, ok := find_in_stack(stack, token.content); ok {
              switch child in child {
                case bool:
                  if child {
                    parse(template[1:end], output, stack, indent+1)
                  }
                case string:
                  // PANIC?
                case Slice:
                  for child in child {
                    if m, ok := child.(Map); ok {
                      stack := stack
                      stack.stack[stack.idx] = m
                      stack.idx += 1
                      parse(template[1:end], output, stack, indent+1)
                    }
                  }
                case Map:
                  stack := stack
                  stack.stack[stack.idx] = child
                  stack.idx += 1
                  parse(template[1:end], output, stack, indent+1)
              }
            }
            next_eat_new_line = true
            fresh_line = false
            template = template[end:]
          } else {
            // PANIC?
          }
        case .Close:
          // PANIC?
      }
    }
  }

  bld := strings.builder_make(allocator)
  parse(tokenized_template[:], &bld, { node.(Map), 1 })

  return strings.to_string(bld)
}
