package main

import "core:fmt"
import "core:runtime"
import "core:mem"
import "core:strings"

import wasm_mem "project:platform/wasm/mem"
import "project:platform/wasm/web"
import "project:platform/wasm/webgl"

import "project:game"
import "project:graphics"
import gl_impl "project:graphics/webgl"
import "project:platform"
import wasm_impl "project:platform/wasm"

////////////////////////////////////////////////////////////////////////////////////////////////////

  has_clicked := false

  /*
    InputButton :: enum {
      KeyW, // qwerty up : workman up
      KeyA, // qwerty left
      KeyS, // qwerty down  : azerty down
      KeyD, // qwerty right : azerty right
      KeyH, // workman left
      KeyT, // workman down
      KeyG, // workman right
      KeyZ, // azerty up
      KeyQ, // azerty left
      KeyUp,    // arrows up
      KeyLeft,  // arrows left
      KeyDown,  // arrows down
      KeyRight, // arrows right
      KeyX, // arrows/qwerty/azerty primary
      KeyC, // arrows/qwerty/azerty secondary
      KeyN, // wasd/qwerty primary
      KeyM, // wasd/qwerty secondary
      KeyK, // whtg/workman primary
      KeyL, // whtg/workman secondary
      // KeyR, // emergency recall
      KeyEnter, // universal primary
      KeySpace, // universal secondary
    }
    InputAction :: enum {
      Up,
      Left,
      Down,
      Right,
      Primary,
      Secondary,
      // Recall,
    }
    raw_input : [InputButton]bool
    input : [InputAction]bool
  */

////////////////////////////////////////////////////////////////////////////////////////////////////

  main :: proc() {
    fmt.println("Stack Size:", f32(wasm_mem.STACK_SIZE) / mem.Kilobyte, "KB")
    fmt.println("Heap Size:", f32(wasm_mem.ARENA_SIZE) / mem.Megabyte, "MB")

    // Memory Allocators
      @(static) arena : mem.Arena
      @(static) scratch_allocator : mem.Scratch_Allocator

      mem.arena_init(&arena, wasm_mem.ARENA_MEMORY[0:wasm_mem.ARENA_SIZE])
      context.allocator = mem.arena_allocator(&arena)

      mem.scratch_allocator_init(&scratch_allocator, wasm_mem.SCRATCH_SIZE)
      context.temp_allocator = mem.scratch_allocator(&scratch_allocator)

      runtime.init_default_context_for_js = context

    // Platform API
      platform.implementation = wasm_impl.implementation
      platform.init()

    // Graphics API
      web.evaluate(`document.body.innerHTML = '<canvas id="c"></canvas>';`)

      web.evaluate(`this.canvas = document.getElementById("c");`)

      graphics.implementation = gl_impl.implementation
      graphics.init()

      if !webgl.IsWebGL2() {
        crash("Could not get a WebGL2 context.")
      }

    // Event Handlers
      resize_canvas :: proc() {
        window_rect := web.window_get_rect()
        buf : [64]u8
        web.evaluate(fmt.bprintf(buf[:], `this.canvas.width = %v;`, window_rect.width))
        web.evaluate(fmt.bprintf(buf[:], `this.canvas.height = %v;`, window_rect.height))
        webgl.Viewport(0, 0, i32(window_rect.width), i32(window_rect.height))
        game.display_resize(int(window_rect.width), int(window_rect.height))
      }

      web.add_window_event_listener(.Resize, nil, proc(e : web.Event) {
        resize_canvas()
      })
      resize_canvas()

      /*
        web.add_window_event_listener(.Key_Down, nil, proc(e : web.Event) {
          if !e.data.key.repeat {
            switch e.data.key.code {
              case "KeyW":
                raw_input[.KeyW] = true
              case "KeyA":
                raw_input[.KeyA] = true
              case "KeyS":
                raw_input[.KeyS] = true
              case "KeyD":
                raw_input[.KeyD] = true
              case "KeyH":
                raw_input[.KeyH] = true
              case "KeyT":
                raw_input[.KeyT] = true
              case "KeyG":
                raw_input[.KeyG] = true
              case "KeyZ":
                raw_input[.KeyZ] = true
              case "KeyQ":
                raw_input[.KeyQ] = true
              case "ArrowUp":
                raw_input[.KeyUp] = true
              case "ArrowLeft":
                raw_input[.KeyLeft] = true
              case "ArrowDown":
                raw_input[.KeyDown] = true
              case "ArrowRight":
                raw_input[.KeyRight] = true
              case "KeyX":
                raw_input[.KeyX] = true
              case "KeyC":
                raw_input[.KeyC] = true
              case "KeyN":
                raw_input[.KeyN] = true
              case "KeyM":
                raw_input[.KeyM] = true
              case "KeyK":
                raw_input[.KeyK] = true
              case "KeyL":
                raw_input[.KeyL] = true
              // case "KeyR":
              //  raw_input[.KeyR] = true
              case "Enter":
                raw_input[.KeyEnter] = true
              case "Space":
                raw_input[.KeySpace] = true
            }
          }
          web.event_prevent_default()
        })
        web.add_window_event_listener(.Key_Up, nil, proc(e : web.Event) {
          switch e.data.key.code {
            case "KeyW":
              raw_input[.KeyW] = false
            case "KeyA":
              raw_input[.KeyA] = false
            case "KeyS":
              raw_input[.KeyS] = false
            case "KeyD":
              raw_input[.KeyD] = false
            case "KeyH":
              raw_input[.KeyH] = false
            case "KeyT":
              raw_input[.KeyT] = false
            case "KeyG":
              raw_input[.KeyG] = false
            case "KeyZ":
              raw_input[.KeyZ] = false
            case "KeyQ":
              raw_input[.KeyQ] = false
            case "ArrowUp":
              raw_input[.KeyUp] = false
            case "ArrowLeft":
              raw_input[.KeyLeft] = false
            case "ArrowDown":
              raw_input[.KeyDown] = false
            case "ArrowRight":
              raw_input[.KeyRight] = false
            case "KeyX":
              raw_input[.KeyX] = false
            case "KeyC":
              raw_input[.KeyC] = false
            case "KeyN":
              raw_input[.KeyN] = false
            case "KeyM":
              raw_input[.KeyM] = false
            case "KeyK":
              raw_input[.KeyK] = false
            case "KeyL":
              raw_input[.KeyL] = false
            // case "KeyR":
            //  raw_input[.KeyR] = false
            case "Enter":
              raw_input[.KeyEnter] = false
            case "Space":
              raw_input[.KeySpace] = false
          }
          web.event_prevent_default()
        })
      */
      web.add_window_event_listener(.Pointer_Down, nil, proc(e : web.Event) {
        if !has_clicked {
          has_clicked = true
          // play_music(.SpaceWalk)
        }
      })
      web.add_window_event_listener(.Context_Menu, nil, proc(e : web.Event) {
        web.event_prevent_default()
      })

    // Start Game
      game.init_game()
  }

////////////////////////////////////////////////////////////////////////////////////////////////////

  @export
  step :: proc(delta_time : f32)
  {
    // web.evaluate("this.canvas.requestPointerLock();")

    TIME_STEP :: f32(1.0/60.0)

    @(static) time_acc : f32
    time_acc += delta_time
    for time_acc > TIME_STEP {
      time_acc -= TIME_STEP
      if has_clicked {
        /*
          input[.Up] =        raw_input[.KeyZ] | raw_input[.KeyW] | raw_input[.KeyUp]
          input[.Left] =      raw_input[.KeyQ] | raw_input[.KeyH] | raw_input[.KeyA] | raw_input[.KeyLeft]
          input[.Down] =      raw_input[.KeyT] | raw_input[.KeyS] | raw_input[.KeyDown]
          input[.Right] =     raw_input[.KeyG] | raw_input[.KeyD] | raw_input[.KeyRight]
          input[.Primary] =   raw_input[.KeyX] | raw_input[.KeyN] | raw_input[.KeyK] | raw_input[.KeyEnter]
          input[.Secondary] = raw_input[.KeyC] | raw_input[.KeyM] | raw_input[.KeyL] | raw_input[.KeySpace]
          // input[.Recall] =    raw_input[.KeyR]
        */
      } else {
        // input = {}
      }

      // game.tick_game()
    }

    game.draw()

    if !has_clicked {
      /*
        draw_screen_rect(0, screen_size, { 0, 0, 0, 0.5 })
        width := get_font_width("CLICK HERE", 1)
        draw_font({ -width/2, -0.5 }, "CLICK HERE", 1, COLOR_WHITE)
      */
    }
  }

  crash :: proc(msg : string, loc := #caller_location) {
    buf : [512]u8
    m, _ := strings.replace_all(msg, "'", "\\'")
    web.evaluate(fmt.bprintf(buf[:], "document.body.innerText = '%v\\n%v';", m, loc))
    runtime.panic(msg, loc)
  }
