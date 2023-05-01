package game

import "core:math/linalg"

import "project:graphics"
import "project:platform"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  @(entity_type)
  EntityEgg :: struct {
    using base : EntityBase,
    start_tile : TilePos,
    iid : string,
    is_hatched : bool,
  }

  hatched_eggs : map[string]struct{}

  EGG_GFX_RECT :: graphics.Rect{ 208.0 / 512.0, 464.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_HATCHED_GFX_RECT :: graphics.Rect{ 208.0 / 512.0, 448.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }
  EGG_HOT_RECT :: graphics.Rect{ 224.0 / 512.0, 464.0 / 512.0, 16.0 / 512.0, 16.0 / 512.0 }

// Messages ////////////////////////////////////////////////////////////////////////////////////////

  @(entity_message=init)
  entity_init_egg :: proc(using egg : ^EntityEgg) {
    start_tile = base._tile_pos
    if _, ok := hatched_eggs[iid]; ok {
      is_hatched = true
    }
  }

  @(entity_message=undo)
  entity_undo_egg :: proc(using egg : ^EntityEgg, using undo : UndoItem) {
    if egg_iid == iid {
      set_tile_pos((^Entity)(egg), base._tile_pos - direction_tile_offset[move_dir])
    }
  }

  @(entity_message=redo)
  entity_redo_egg :: proc(using egg : ^EntityEgg, using undo : UndoItem) {
    if egg_iid == iid {
      set_tile_pos((^Entity)(egg), base._tile_pos + direction_tile_offset[move_dir])
    }
  }

  @(entity_message=reset)
  entity_reset_egg :: proc(using egg : ^EntityEgg) {
    set_tile_pos((^Entity)(egg), start_tile)
  }

  @(entity_message=draw)
  entity_draw_egg :: proc(using egg : ^EntityEgg, material : graphics.MaterialSprite) {
    material := material
    material.spritesheet = get_texture(.Tileset)
    material.render_order += 1

    if is_hatched {
      material.rect = EGG_HATCHED_GFX_RECT
    } else {
      if world_get_tile_at(base._tile_pos) == .Hot {
        material.rect = EGG_HOT_RECT
      } else {
        material.rect = EGG_GFX_RECT
      }
    }
    pos := linalg.Vector3f32{ f32(base._tile_pos.x), f32(base._tile_pos.y), 0 }
    graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_translate_f32(pos))
  }

  @(entity_message=get_collision) // TODO (hitch) 2023-04-29 This should only be _at called!
  entity_get_collidion_egg :: proc(using egg : ^EntityEgg, movin_entity : ^Entity, move_dir : Direction) -> (result : CollisionResult) {
    if is_hatched {
      return {}
    }

    if _, ok := movin_entity.(EntityDragon); ok {
      if world_can_move_to((^Entity)(egg), base._tile_pos+direction_tile_offset[move_dir], move_dir) {
        return {}
      }
    }
    return { .Solid }
  }

  @(entity_message=enter) // TODO (hitch) 2023-04-29 This should only be _at called!
  entity_enter_egg :: proc(using egg : ^EntityEgg, moving_entitiy : ^Entity, move_dir : Direction) {
    if !is_hatched {
      set_tile_pos((^Entity)(egg), base._tile_pos + direction_tile_offset[move_dir])
      history[history_current].egg_iid = iid
      if world_get_tile_at(base._tile_pos) == .Hot {
        platform.play_sound(sounds.egg_hot)
      } else {
        platform.play_sound(sounds.egg_push)
      }
    }
  }

  @(entity_message=hatch_eggs) // TODO (hitch) 2023-04-29 This should only be _at called!
  entity_hatch_eggs_egg :: proc(using egg : ^EntityEgg) {
    if !is_hatched {
      if world_get_tile_at(base._tile_pos) == .Hot {
        platform.play_sound(sounds.egg_hatch)
        is_hatched = true
        hatched_eggs[iid] = {}
        eggs_collected += 1
      }
    }
  }
