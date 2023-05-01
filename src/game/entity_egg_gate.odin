package game

import "core:math/linalg"

import "project:graphics"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  @(entity_type)
  EntityEggGate :: struct {
    using base : EntityBase,
    egg_count : int,
  }

  EGG_1_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 208.0 / 512.0, 432.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_3_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 224.0 / 512.0, 432.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_6_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 240.0 / 512.0, 432.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_5_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 256.0 / 512.0, 432.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_8_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 272.0 / 512.0, 432.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_14_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 288.0 / 512.0, 432.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

  EGG_1_GATE_OPENED_GFX_RECT :: graphics.Rect{ 208.0 / 512.0, 416.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_3_GATE_OPENED_GFX_RECT :: graphics.Rect{ 224.0 / 512.0, 416.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_6_GATE_OPENED_GFX_RECT :: graphics.Rect{ 240.0 / 512.0, 416.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_5_GATE_OPENED_GFX_RECT :: graphics.Rect{ 256.0 / 512.0, 416.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_8_GATE_OPENED_GFX_RECT :: graphics.Rect{ 272.0 / 512.0, 416.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_14_GATE_OPENED_GFX_RECT :: graphics.Rect{ 288.0 / 512.0, 416.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

// Messages ////////////////////////////////////////////////////////////////////////////////////////

  @(entity_message=draw)
  entity_draw_egg_gate :: proc(using egg_gate : ^EntityEggGate, material : graphics.MaterialSprite) {
    material := material
    material.spritesheet = get_texture(.Tileset)

    pos := linalg.Vector3f32{ f32(base._tile_pos.x), f32(base._tile_pos.y), 0 }
    if eggs_collected >= egg_count {
      switch egg_count {
        case 1:
          material.rect = EGG_1_GATE_OPENED_GFX_RECT
        case 3:
          material.rect = EGG_3_GATE_OPENED_GFX_RECT
        case 6:
          material.rect = EGG_6_GATE_OPENED_GFX_RECT
        case 5:
          material.rect = EGG_5_GATE_OPENED_GFX_RECT
        case 8:
          material.rect = EGG_8_GATE_OPENED_GFX_RECT
        case 14:
          material.rect = EGG_14_GATE_OPENED_GFX_RECT
      }
      graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos))
    } else {
      material := graphics.MaterialEggDoor{
        spritesheet = material.spritesheet,
        egg_count = eggs_collected,
        blend_mode = material.blend_mode,
        color = material.color,
        render_order = material.render_order,
        sorting = material.sorting,
        flags = material.flags,
        alpha_clip = material.alpha_clip,
      }
      switch egg_count {
        case 1:
          material.rect = EGG_1_GATE_CLOSED_GFX_RECT
        case 3:
          material.rect = EGG_3_GATE_CLOSED_GFX_RECT
        case 6:
          material.rect = EGG_6_GATE_CLOSED_GFX_RECT
        case 5:
          material.rect = EGG_5_GATE_CLOSED_GFX_RECT
        case 8:
          material.rect = EGG_8_GATE_CLOSED_GFX_RECT
        case 14:
          material.rect = EGG_14_GATE_CLOSED_GFX_RECT
      }
      graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos))
    }
  }

  @(entity_message=get_collision) // TODO (hitch) 2023-04-29 This should only be _at called!
  entity_get_collidion_egg_gate :: proc(using egg_gate : ^EntityEggGate) -> (result : CollisionResult) {
    if eggs_collected >= egg_count {
      return {}
    } else {
      return { .Solid }
    }
  }
