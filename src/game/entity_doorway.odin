package game

import "core:math/linalg"

import "project:graphics"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  @(entity_type)
  EntityDoorway :: struct {
    using base : EntityBase,
    facing : Direction,
    linked_door : string,
  }

  DOOR_GFX_RECT :: graphics.Rect{ 288.0 / 512.0, 464.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

// Messages ////////////////////////////////////////////////////////////////////////////////////////

  @(entity_message=draw)
  entity_draw_door :: proc(using door : ^EntityDoorway, material : graphics.MaterialSprite) {
    material := material
    material.spritesheet = get_texture(.Tileset)

    rotations := [Direction]linalg.Matrix4f32 {
      .None = 1,
      .Left = 1,
      .Up = linalg.matrix4_rotate_f32(-0.5 * linalg.PI, { 0, 0, 1 }),
      .Right = linalg.matrix4_rotate_f32(linalg.PI, { 0, 0, 1 }),
      .Down = linalg.matrix4_rotate_f32(0.5 * linalg.PI, { 0, 0, 1 }),
    }

    material.rect = DOOR_GFX_RECT
    material.render_order -= 1
    pos := linalg.Vector3f32{ f32(base._tile_pos.x), f32(base._tile_pos.y), 0 }
    graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos) * rotations[facing])
  }

  @(entity_message=exit) // TODO (hitch) 2023-04-29 This should only be _at called!
  entity_exit_door :: proc(using door : ^EntityDoorway, moving_entitiy : ^Entity, move_dir : Direction) {
    if linked_door != "" {
      if dragon, ok := &moving_entitiy.(EntityDragon); ok {
        if move_dir == direction_back_direction[facing] {
          entity_hatch_eggs_all()
          target := world.doorways[linked_door]
          set_dragon_reset(dragon, target.pos, target.dir, target.flip)
        }
      }
    }
  }

  @(entity_message=get_exit_collision) // TODO (hitch) 2023-04-29 This should only be _at called!
  entity_get_exit_collision_door :: proc(using door : ^EntityDoorway, exiting_entity : ^Entity, move_dir : Direction) -> (result : CollisionResult) {
    if _, ok := exiting_entity.(EntityDragon); ok {
      if move_dir == direction_back_direction[facing] {
        return { .Force_Support }
      }
    }
    return
  }
