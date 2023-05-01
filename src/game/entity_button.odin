package game

import "core:math/linalg"

import "project:graphics"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  @(entity_type)
  EntityButton :: struct {
    using base : EntityBase,
    channel : ButtonChannel,
  }

  ButtonChannel :: enum { CH_1, CH_2, CH_3, CH_4 }

  BUTTON_1_GFX_RECT :: graphics.Rect{ 304.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_2_GFX_RECT :: graphics.Rect{ 320.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_3_GFX_RECT :: graphics.Rect{ 336.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  BUTTON_4_GFX_RECT :: graphics.Rect{ 352.0 / 512.0, 496.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

// Messages ////////////////////////////////////////////////////////////////////////////////////////

  @(entity_message=draw)
  entity_draw_button :: proc(using button : ^EntityButton, material : graphics.MaterialSprite) {
    material := material
    material.spritesheet = get_texture(.Tileset)

    switch channel {
      case .CH_1:
        material.rect = BUTTON_1_GFX_RECT
      case .CH_2:
        material.rect = BUTTON_2_GFX_RECT
      case .CH_3:
        material.rect = BUTTON_3_GFX_RECT
      case .CH_4:
        material.rect = BUTTON_4_GFX_RECT
    }
    pos := linalg.Vector3f32{ f32(base._tile_pos.x), f32(base._tile_pos.y), 0 }
    graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos))
  }

  @(entity_message=update_passive_state)
  entity_update_passive_state_button :: proc(using button : ^EntityButton) {
    dragon := &entity_lookup[dragon].(EntityDragon)
    if get_dragon_in_tile(dragon, base._tile_pos) {
      button_state |= { channel }
    }
  }
