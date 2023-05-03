package main

import "core:fmt"
import "core:runtime"
import "core:mem"
import "core:strings"
import "core:math/linalg"

import wasm_mem "project:platform/wasm/mem"
import "project:platform/wasm/web"
import "project:platform/wasm/webgl"

import "project:game"
import "project:graphics"
import gl_impl "project:graphics/webgl"
import "project:platform"
import wasm_impl "project:platform/wasm"

////////////////////////////////////////////////////////////////////////////////////////////////////

  canvas_rect : web.Rect
  has_clicked := false
  has_focus := false
  ready_for_touch := false
  show_touch_input := false
  NAG_SCREEN_GFX_RECT :: graphics.Rect{ 256.0 / 512.0, 208.0 / 512.0, 192.0 / 512.0, 144.0 / 512.0 }
  INPUT_ARROW_GFX_RECT :: graphics.Rect{ 256.0 / 512.0, 176.0 / 512.0, 23.0 / 512.0, 31.0 / 512.0 }
  INPUT_UNDO_GFX_RECT :: graphics.Rect{ 288.0 / 512.0, 176.0 / 512.0, 22.0 / 512.0, 27.0 / 512.0 }

  @(private="file")
  raw_input, last_raw_input : struct {
    win_close : bool,

    touch_start : bool,
    touch_undo : bool,
    touch_redo : bool,
    touch_up : bool,
    touch_left : bool,
    touch_down : bool,
    touch_right : bool,

    key_enter : bool,
    key_w : bool,
    key_a : bool,
    key_s : bool,
    key_d : bool,
    key_z : bool,
    key_q : bool,
    key_h : bool,
    key_t : bool,
    key_g : bool,
    key_x : bool,
    key_c : bool,
    key_r : bool,
    key_up : bool,
    key_down : bool,
    key_left : bool,
    key_right : bool,
  }

////////////////////////////////////////////////////////////////////////////////////////////////////

  main :: proc() {
    // fmt.println("Stack Size:", f32(wasm_mem.STACK_SIZE) / mem.Kilobyte, "KB")
    // fmt.println("Heap Size:", f32(wasm_mem.ARENA_SIZE) / mem.Megabyte, "MB")

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
      web.evaluate(`document.body.innerHTML = '<canvas id="c" style="position:absolute;top:0;left:0;right:0;bottom:0;margin:auto;"></canvas>';`)

      web.evaluate(`this.canvas = document.getElementById("c");`)

      graphics.implementation = gl_impl.implementation
      graphics.init()

      if !webgl.IsWebGL2() {
        crash("Could not get a WebGL2 context.")
      }

    // Event Handlers
      resize_canvas :: proc() {
        ASPECT :: f64(game.ROOM_WIDTH) / f64(game.ROOM_HEIGHT)
        window_rect := web.window_get_rect()
        buf : [64]u8
        width := window_rect.width
        height := window_rect.height
        if (width / height) > ASPECT {
          width = height * ASPECT
        } else {
          height = width / ASPECT
        }
        web.evaluate(fmt.bprintf(buf[:], `this.canvas.width = %v;`, width))
        web.evaluate(fmt.bprintf(buf[:], `this.canvas.height = %v;`, height))
        webgl.Viewport(0, 0, i32(width), i32(height))
        game.display_resize(int(width), int(height))
        canvas_rect = web.get_bounding_client_rect("c")
      }

      web.add_window_event_listener(.Resize, nil, proc(e : web.Event) {
        resize_canvas()
      })
      resize_canvas()

      web.add_window_event_listener(.Key_Down, nil, proc(e : web.Event) {
        // show_touch_input = false
        if !e.data.key.repeat {
          switch e.data.key.code {
            case "Enter":
              raw_input.key_enter = true
            case "KeyW":
              raw_input.key_w = true
            case "KeyA":
              raw_input.key_a = true
            case "KeyS":
              raw_input.key_s = true
            case "KeyD":
              raw_input.key_d = true
            case "KeyZ":
              raw_input.key_z = true
            case "KeyQ":
              raw_input.key_q = true
            case "KeyH":
              raw_input.key_h = true
            case "KeyT":
              raw_input.key_t = true
            case "KeyG":
              raw_input.key_g = true
            case "KeyX":
              raw_input.key_x = true
            case "KeyC":
              raw_input.key_c = true
            case "KeyR":
              raw_input.key_r = true
            case "ArrowUp":
              raw_input.key_up = true
            case "ArrowLeft":
              raw_input.key_left = true
            case "ArrowDown":
              raw_input.key_down = true
            case "ArrowRight":
              raw_input.key_right = true
          }
        }
        web.event_prevent_default()
      })
      web.add_window_event_listener(.Key_Up, nil, proc(e : web.Event) {
        switch e.data.key.code {
          case "Enter":
            raw_input.key_enter = false
          case "KeyW":
            raw_input.key_w = false
          case "KeyA":
            raw_input.key_a = false
          case "KeyS":
            raw_input.key_s = false
          case "KeyD":
            raw_input.key_d = false
          case "KeyZ":
            raw_input.key_z = false
          case "KeyQ":
            raw_input.key_q = false
          case "KeyH":
            raw_input.key_h = false
          case "KeyT":
            raw_input.key_t = false
          case "KeyG":
            raw_input.key_g = false
          case "KeyX":
            raw_input.key_x = false
          case "KeyC":
            raw_input.key_c = false
          case "KeyR":
            raw_input.key_r = false
          case "ArrowUp":
            raw_input.key_up = false
          case "ArrowLeft":
            raw_input.key_left = false
          case "ArrowDown":
            raw_input.key_down = false
          case "ArrowRight":
            raw_input.key_right = false

        }
        web.event_prevent_default()
      })
      web.add_window_event_listener(.Touch_Start, nil, proc(e : web.Event) {
        if ready_for_touch {
          raw_input.touch_start = true
          show_touch_input = true
        }
      })
      web.add_window_event_listener(.Pointer_Down, nil, proc(e : web.Event) {
        if show_touch_input {
          SCREEN_TOP :: 0.0
          SCREEN_BOTTOM :: 16.0 * game.ROOM_HEIGHT
          SCREEN_LEFT :: 0.0
          SCREEN_RIGHT :: 16.0 * game.ROOM_WIDTH

          pos := [2]f64{ f64(e.mouse.client.x), f64(e.mouse.client.y) }
          pos -= { canvas_rect.x, canvas_rect.y }
          pos /= { canvas_rect.width, canvas_rect.height }
          pos *= { 16*game.ROOM_WIDTH, 16*game.ROOM_HEIGHT }

          check_button :: proc(pos : [2]f64, center : [2]f64, radius : f64) -> bool {
            return abs(pos.x-center.x) + abs(pos.y-center.y) <= radius
          }

          if check_button(pos, { SCREEN_LEFT + 10, SCREEN_TOP + 10 }, 25) {
            raw_input.touch_undo = true
          }

          if check_button(pos, { SCREEN_RIGHT - 10, SCREEN_TOP + 10 }, 25) {
            raw_input.touch_redo = true
          }

          if check_button(pos, { SCREEN_RIGHT - (31+3.5), SCREEN_BOTTOM - ((31+3.5) + (3.5+15.5+5)) }, 20) {
            raw_input.touch_up = true
          }

          if check_button(pos, { SCREEN_RIGHT - ((31+3.5) + (3.5+15.5+5)), SCREEN_BOTTOM - (31+3.5) }, 20) {
            raw_input.touch_left = true
          }

          if check_button(pos, { SCREEN_RIGHT - (31+3.5), SCREEN_BOTTOM - ((31+3.5) - (3.5+15.5+5)) }, 20) {
            raw_input.touch_down = true
          }

          if check_button(pos, { SCREEN_RIGHT - ((31+3.5) - (3.5+15.5+5)), SCREEN_BOTTOM - (31+3.5) }, 20) {
            raw_input.touch_right = true
          }
        }
        if !has_clicked {
          has_clicked = true
          has_focus = true
          web.evaluate(`document.body.style.background = "#1C0639"`)
          game.audio_ready()
        }
      })
      web.add_window_event_listener(.Context_Menu, nil, proc(e : web.Event) {
        web.event_prevent_default()
      })
      web.add_window_event_listener(.Focus, nil, proc(e : web.Event) {
        has_focus = true
        web.evaluate(`document.body.style.background = "#1C0639"`)
      })
      web.add_window_event_listener(.Blur, nil, proc(e : web.Event) {
        has_focus = false
        web.evaluate(`document.body.style.background = "#090212"`)
      })

    // Start Game
      game.init_game()
  }

////////////////////////////////////////////////////////////////////////////////////////////////////

  input : game.Input

  @export
  step :: proc(delta_time : f32)
  {
    if has_clicked {
      input.enter_press = (raw_input.key_enter && !last_raw_input.key_enter) || raw_input.touch_start
      input.undo_press = (raw_input.key_x && !last_raw_input.key_x) || raw_input.touch_undo
      input.redo_press = (raw_input.key_c && !last_raw_input.key_c) || raw_input.touch_redo
      input.reset_press = (raw_input.key_r && !last_raw_input.key_r)
      input.up_press = (raw_input.key_up && !last_raw_input.key_up) ||
                       (raw_input.key_w && !last_raw_input.key_w) ||
                       (raw_input.key_z && !last_raw_input.key_z) ||
                       (raw_input.touch_up)
      input.left_press = (raw_input.key_left && !last_raw_input.key_left) ||
                         (raw_input.key_a && !last_raw_input.key_a) ||
                         (raw_input.key_h && !last_raw_input.key_h) ||
                         (raw_input.key_q && !last_raw_input.key_q) ||
                         (raw_input.touch_left)
      input.down_press = (raw_input.key_down && !last_raw_input.key_down) ||
                         (raw_input.key_s && !last_raw_input.key_s) ||
                         (raw_input.key_t && !last_raw_input.key_t) ||
                         (raw_input.touch_down)
      input.right_press = (raw_input.key_right && !last_raw_input.key_right) ||
                          (raw_input.key_d && !last_raw_input.key_d) ||
                          (raw_input.key_g && !last_raw_input.key_g) ||
                          (raw_input.touch_right)
    } else {
      input = {}
    }
    last_raw_input = raw_input
    raw_input.touch_start = false
    raw_input.touch_undo = false
    raw_input.touch_redo = false
    raw_input.touch_up = false
    raw_input.touch_left = false
    raw_input.touch_down = false
    raw_input.touch_right = false


    input.delta_time = f64(delta_time)
    input.close_window = false
    input.esc_press = false
    game.update(input)
    game.draw()

    if !has_clicked || !has_focus {
      graphics.set_camera_matrix(1)

      sprite_material := graphics.MaterialSprite{
        spritesheet = game.get_texture(.Tileset),
        rect = NAG_SCREEN_GFX_RECT,
        blend_mode = .Alpha_Blend,
        render_order = 1_000_000,
        color = { 1, 1, 1, 1 },
        flags = { .Disable_Z_Test, .Disable_Z_Write, .Disable_Back_Culling },
      }
      graphics.queue_draw_mesh(game.meshes.quad, sprite_material, linalg.matrix4_scale_f32({ 12.01, 9.01, 1 }))
      graphics.flush_queue()
    } else {
      ready_for_touch = true
      if show_touch_input {
        graphics.set_camera_matrix(1)

        sprite_material := graphics.MaterialSprite{
          spritesheet = game.get_texture(.Tileset),
          rect = INPUT_UNDO_GFX_RECT,
          blend_mode = .Alpha_Blend,
          color = { 1, 1, 1, 0.25 },
          flags = { .Disable_Z_Test, .Disable_Z_Write, .Disable_Back_Culling },
        }
        PX_TO_SCREEN :: 1.0 / 16.0
        SCREEN_TOP :: game.ROOM_HEIGHT / 2.0
        SCREEN_BOTTOM :: -game.ROOM_HEIGHT / 2.0
        SCREEN_LEFT :: -game.ROOM_WIDTH / 2.0
        SCREEN_RIGHT :: game.ROOM_WIDTH / 2.0

        graphics.queue_draw_mesh(game.meshes.quad, sprite_material, linalg.matrix4_translate_f32({ SCREEN_LEFT + (11 * PX_TO_SCREEN), SCREEN_TOP - (13.5 * PX_TO_SCREEN), 0 }) * linalg.matrix4_scale_f32({ 1.375, 1.6875, 1 }))
        graphics.queue_draw_mesh(game.meshes.quad, sprite_material, linalg.matrix4_translate_f32({ SCREEN_RIGHT - (11 * PX_TO_SCREEN), SCREEN_TOP - (13.5 * PX_TO_SCREEN), 0 }) * linalg.matrix4_scale_f32({ -1.375, 1.6875, 1 }))

        sprite_material.rect = INPUT_ARROW_GFX_RECT
        graphics.queue_draw_mesh(game.meshes.quad, sprite_material, linalg.matrix4_translate_f32({ SCREEN_RIGHT - ((31+3.5) * PX_TO_SCREEN), SCREEN_BOTTOM + (((31+3.5) + (3.5+15.5)) * PX_TO_SCREEN), 0 }) * linalg.matrix4_scale_f32({ 1.5, 1.9375, 1 }))
        graphics.queue_draw_mesh(game.meshes.quad, sprite_material, linalg.matrix4_translate_f32({ SCREEN_RIGHT - (((31+3.5) + (3.5+15.5)) * PX_TO_SCREEN), SCREEN_BOTTOM + ((31+3.5) * PX_TO_SCREEN), 0 }) * linalg.matrix4_rotate_f32(0.5*linalg.PI, { 0, 0, 1 }) * linalg.matrix4_scale_f32({ 1.5, 1.9375, 1 }))
        graphics.queue_draw_mesh(game.meshes.quad, sprite_material, linalg.matrix4_translate_f32({ SCREEN_RIGHT - ((31+3.5) * PX_TO_SCREEN), SCREEN_BOTTOM + (((31+3.5) - (3.5+15.5)) * PX_TO_SCREEN), 0 }) * linalg.matrix4_rotate_f32(linalg.PI, { 0, 0, 1 }) * linalg.matrix4_scale_f32({ 1.5, 1.9375, 1 }))
        graphics.queue_draw_mesh(game.meshes.quad, sprite_material, linalg.matrix4_translate_f32({ SCREEN_RIGHT - (((31+3.5) - (3.5+15.5)) * PX_TO_SCREEN), SCREEN_BOTTOM + ((31+3.5) * PX_TO_SCREEN), 0 }) * linalg.matrix4_rotate_f32(1.5*linalg.PI, { 0, 0, 1 }) * linalg.matrix4_scale_f32({ 1.5, 1.9375, 1 }))

        graphics.flush_queue()
      }
    }
  }

  crash :: proc(msg : string, loc := #caller_location) {
    buf : [512]u8
    m, _ := strings.replace_all(msg, "'", "\\'")
    web.evaluate(fmt.bprintf(buf[:], "document.body.innerText = '%v\\n%v';", m, loc))
    runtime.panic(msg, loc)
  }
