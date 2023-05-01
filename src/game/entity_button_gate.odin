package game

import "core:math/linalg"

import "project:graphics"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  @(entity_type)
  EntityButtonGate :: struct {
    using base : EntityBase,
    channel : ButtonChannel,
  }

  BUTTON_1_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 304.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_2_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 320.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_3_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 336.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_4_GATE_CLOSED_GFX_RECT :: graphics.Rect{ 352.0 / 512.0, 480.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

  BUTTON_1_GATE_OPENED_GFX_RECT :: graphics.Rect{ 304.0 / 512.0, 464.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_2_GATE_OPENED_GFX_RECT :: graphics.Rect{ 320.0 / 512.0, 464.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_3_GATE_OPENED_GFX_RECT :: graphics.Rect{ 336.0 / 512.0, 464.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_4_GATE_OPENED_GFX_RECT :: graphics.Rect{ 352.0 / 512.0, 464.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

// Messages ////////////////////////////////////////////////////////////////////////////////////////

  @(entity_message=draw)
  entity_draw_button_gate :: proc(using button_gate : ^EntityButtonGate, material : graphics.MaterialSprite) {
    material := material
    material.spritesheet = get_texture(.Tileset)

    if channel in button_state {
      switch channel {
        case .CH_1:
          material.rect = BUTTON_1_GATE_OPENED_GFX_RECT
        case .CH_2:
          material.rect = BUTTON_2_GATE_OPENED_GFX_RECT
        case .CH_3:
          material.rect = BUTTON_3_GATE_OPENED_GFX_RECT
        case .CH_4:
          material.rect = BUTTON_4_GATE_OPENED_GFX_RECT
      }
    } else {
      switch channel {
        case .CH_1:
          material.rect = BUTTON_1_GATE_CLOSED_GFX_RECT
        case .CH_2:
          material.rect = BUTTON_2_GATE_CLOSED_GFX_RECT
        case .CH_3:
          material.rect = BUTTON_3_GATE_CLOSED_GFX_RECT
        case .CH_4:
          material.rect = BUTTON_4_GATE_CLOSED_GFX_RECT
      }
    }
    pos := linalg.Vector3f32{ f32(base._tile_pos.x), f32(base._tile_pos.y), 0 }
    graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos))
  }

  @(entity_message=get_collision) // TODO (hitch) 2023-04-29 This should only be _at called!
  entity_get_collidion_button_gate :: proc(using button_gate : ^EntityButtonGate) -> (result : CollisionResult) {
    if channel in button_state {
      return {}
    } else {
      return { .Solid }
    }
  }
