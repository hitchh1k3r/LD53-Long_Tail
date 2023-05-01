package game

import "core:math/linalg"
import "core:mem"

import "project:graphics"
import "project:platform"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  @(entity_type)
  EntityDragon :: struct {
    using base : EntityBase,
    start_tile : TilePos,
    start_facing : Direction,
    facing : Direction,
    flipped : bool,
    head_pos : f32,
  }

  @(private="file")
  tail : [128]Direction

  DRAGON_HEAD_RECT :: graphics.Rect{ 208.0 / 512.0, 496.0 / 512.0, 32.0 / 512.0, 16.0 / 512.0 }
  DRAGON_STRAIGHT_RECT :: graphics.Rect{ 240.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  DRAGON_TAIL_RECT :: graphics.Rect{ 256.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  DRAGON_CCW_BEND_RECT :: graphics.Rect{ 272.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  DRAGON_CW_BEND_RECT :: graphics.Rect{ 288.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

  DRAGON_FLIP_HEAD_RECT :: graphics.Rect{ 208.0 / 512.0, 480.0 / 512.0, 32.0 / 512.0, 16.0 / 512.0 }
  DRAGON_FLIP_STRAIGHT_RECT :: graphics.Rect{ 240.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  DRAGON_FLIP_TAIL_RECT :: graphics.Rect{ 256.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  DRAGON_FLIP_CCW_BEND_RECT :: graphics.Rect{ 272.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  DRAGON_FLIP_CW_BEND_RECT :: graphics.Rect{ 288.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

// Messages ////////////////////////////////////////////////////////////////////////////////////////

  @(entity_message=init)
  entity_init_dragon :: proc(using dragon : ^EntityDragon) {
    start_tile = base._tile_pos
    start_facing = facing
  }

  @(entity_message=press_dir)
  entity_press_dir_dragon :: proc(using dragon : ^EntityDragon, dir : Direction) {
    if dir != .None && animation == .None {
      new_pos := base._tile_pos + direction_tile_offset[dir]
      if world_can_move_to((^Entity)(dragon), new_pos, dir) {
        history[history_current].egg_iid = ""
        platform.play_sound(sounds.move)
        copy_slice(tail[1:], tail[:])
        tail[0] = facing
        facing = dir
        old_pos := base._tile_pos
        set_tile_pos((^Entity)(dragon), new_pos)
        entity_enter_at(new_pos, dir, (^Entity)(dragon))
        entity_exit_at(old_pos, dir, (^Entity)(dragon))
        old_card := card(button_state)
        button_state = {}
        find_current_room()
        entity_update_passive_state_all()
        if card(button_state) > old_card {
          platform.play_sound(sounds.button_press)
        }
        animation = .Move
        animation_timer = 0
        if history_current >= 0 {
          history[history_current].move_dir = dir
        }
        history_current += 1
        history_len = history_current
      } else {
        platform.play_sound(sounds.invalid_move)
        animation = .Invalid
        animation_timer = 0
      }
    }
  }

  @(entity_message=undo)
  entity_undo_dragon :: proc(using dragon : ^EntityDragon, using undo : UndoItem) {
    set_tile_pos((^Entity)(dragon), base._tile_pos - direction_tile_offset[move_dir])
    facing = tail[0]
    copy_slice(tail[:], tail[1:])
  }

  @(entity_message=redo)
  entity_redo_dragon :: proc(using dragon : ^EntityDragon, using undo : UndoItem) {
    copy_slice(tail[1:], tail[:])
    tail[0] = facing
    facing = move_dir
    set_tile_pos((^Entity)(dragon), base._tile_pos + direction_tile_offset[move_dir])
  }

  @(entity_message=reset)
  entity_reset_dragon :: proc(using dragon : ^EntityDragon) {
    mem.set(&tail[0], 0, size_of(tail))
    set_tile_pos((^Entity)(dragon), start_tile)
    facing = start_facing
  }

  @(entity_message=draw)
  entity_draw_dragon :: proc(using dragon : ^EntityDragon, material : graphics.MaterialSprite) {
    material := material
    material.spritesheet = get_texture(.Tileset)

    rotations := [Direction]linalg.Matrix4f32 {
      .None = 1,
      .Left = 1,
      .Up = linalg.matrix4_rotate_f32(-0.5 * linalg.PI, { 0, 0, 1 }),
      .Right = linalg.matrix4_rotate_f32(linalg.PI, { 0, 0, 1 }),
      .Down = linalg.matrix4_rotate_f32(0.5 * linalg.PI, { 0, 0, 1 }),
    }

    material.render_order += 128
    material.rect = flipped ? DRAGON_FLIP_HEAD_RECT : DRAGON_HEAD_RECT
    pos := linalg.Vector3f32{ f32(base._tile_pos.x), f32(base._tile_pos.y), 0 }
    graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos + (head_pos-0.5)*direction_offsets[facing]) * rotations[facing] * linalg.matrix4_scale_f32({ 2, 1, 1 }))
    pos -= direction_offsets[facing]
    material.render_order -= 1

    last_dir := facing
    for dir in tail {
      if dir == .None {
        break
      }

      if last_dir == dir {
        material.rect = flipped ? DRAGON_FLIP_STRAIGHT_RECT : DRAGON_STRAIGHT_RECT
        graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos) * rotations[dir])
      } else if (direction_cw_direction[dir] == last_dir) {
        material.rect = flipped ? DRAGON_FLIP_CW_BEND_RECT : DRAGON_CW_BEND_RECT
        graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos) * rotations[dir])
      } else {
        material.rect = flipped ? DRAGON_FLIP_CCW_BEND_RECT : DRAGON_CCW_BEND_RECT
        graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos) * rotations[dir])
      }
      pos -= direction_offsets[dir]
      last_dir = dir
      material.render_order -= 1
    }

    material.rect = flipped ? DRAGON_FLIP_TAIL_RECT : DRAGON_TAIL_RECT
    graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos) * rotations[last_dir])
  }

  @(entity_message=update_animation)
  entity_update_animation_dragon :: proc(using dragon : ^EntityDragon, animation : Animation, timer : f32) {
    #partial switch animation {
      case .Move:
        head_pos = -0.75 + 0.75*timer
      case .Invalid:
        if timer < 0.5 {
          head_pos = 0.5*(timer)
        } else {
          head_pos = 0.25 - 0.5*(timer-0.5)
        }
    }
  }

// Interfact ///////////////////////////////////////////////////////////////////////////////////////

  set_dragon_reset :: proc(using dragon : ^EntityDragon, pos : TilePos, dir : Direction, flip : bool) {
    start_tile = pos + direction_tile_offset[dir]
    start_facing = dir
    flipped = flip
    mem.set(&tail[0], 0, size_of(tail))
    set_tile_pos((^Entity)(dragon), start_tile)
    facing = start_facing
  }

  get_dragon_collision :: proc(using dragon : ^EntityDragon, tile_pos : TilePos, entity : ^Entity, move_dir : Direction) -> CollisionResult {
    pos := base._tile_pos
    if pos == tile_pos {
      // head 1
      return { .Solid }
    }
    pos -= direction_tile_offset[facing]
    if pos == tile_pos {
      // head 2
      return { .Solid }
    }
    next_dir := facing
    for dir in tail {
      if pos == tile_pos {
        // tail
        if _, ok := entity.(EntityDragon); ok {
          if move_dir == .None || dir == move_dir || direction_back_direction[next_dir] == move_dir {
            return { .Solid }
          }
        } else {
          return { .Solid }
        }
      }
      if dir == .None {
        break
      }
      pos -= direction_tile_offset[dir]
      next_dir = dir
    }

    return {}
  }

  get_dragon_in_tile :: proc(using dragon : ^EntityDragon, tile_pos : TilePos) -> bool {
    pos := base._tile_pos
    if pos == tile_pos {
      return true
    }
    pos -= direction_tile_offset[facing]
    if pos == tile_pos {
      return true
    }
    for dir in tail {
      if dir == .None {
        break
      }
      pos -= direction_tile_offset[dir]
      if pos == tile_pos {
        return true
      }
    }

    return false
  }
