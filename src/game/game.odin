package game

import "core:math"
import "core:math/linalg"

import "project:graphics"
import "project:platform"

CAMERA_SCALE :: 1
NO_CLIP :: false

START_SCREEN_GFX_RECT :: graphics.Rect{ 16.0 / 512.0, 208.0 / 512.0, 190.0 / 512.0, 144.0 / 512.0 }

Input :: struct {
  delta_time : f64,
  close_window : bool,
  esc_press : bool,
  enter_press : bool,
  undo_press : bool,
  redo_press : bool,
  reset_press : bool,
  up_press : bool,
  down_press : bool,
  left_press : bool,
  right_press : bool,
}

is_running := true
dragon : EntityHandle
eggs_collected : int
button_state : bit_set[ButtonChannel]

Animation :: enum {
  None,
  Move,
  Invalid,
}

animation : Animation
animation_timer : f32

camera_pos : V3
camera_target : V3

queued_level_unload : LoadedLevel

splash_screen := true

sounds : struct {
  move : platform.Sound,
  invalid_move : platform.Sound,
  egg_hot : platform.Sound,
  egg_hatch : platform.Sound,
  egg_push : platform.Sound,
  button_press : platform.Sound,
}

music : struct {
  bg_music : platform.Sound,
}

init_game :: proc() {
  graphics.set_clear_color({ 0.10980392156862745, 0.023529411764705882, 0.2235294117647059, 0.0 })

  load_default_graphics()

  init_world_pos()
  dragon = new_entity(EntityDragon{})
  load_world()
  find_current_room()
  camera_pos = camera_target
}

audio_ready :: proc() {
  if bg_music_data, ok := platform.load_resource(.Music); ok {
    music.bg_music, _ = platform.create_sound(bg_music_data, true, true)
    platform.play_sound(music.bg_music)
  }

  if sound_data, ok := platform.load_resource(.Move); ok {
    sounds.move, _ = platform.create_sound(sound_data)
  }

  if sound_data, ok := platform.load_resource(.Invalid); ok {
    sounds.invalid_move, _ = platform.create_sound(sound_data)
  }

  if sound_data, ok := platform.load_resource(.Egg_Hot); ok {
    sounds.egg_hot, _ = platform.create_sound(sound_data)
  }

  if sound_data, ok := platform.load_resource(.Egg_Hatch); ok {
    sounds.egg_hatch, _ = platform.create_sound(sound_data)
  }

  if sound_data, ok := platform.load_resource(.Egg_Push); ok {
    sounds.egg_push, _ = platform.create_sound(sound_data)
  }

  if sound_data, ok := platform.load_resource(.Button_Press); ok {
    sounds.button_press, _ = platform.create_sound(sound_data)
  }
}

history : [256]UndoItem
history_current : int
history_len : int

UndoItem :: struct {
  move_dir : Direction,
  egg_iid : string,
}

LoadedLevel :: struct {
  using level_data : ^Level,
  loaded_entities : [dynamic]EntityHandle,
}

current_level : LoadedLevel
last_level : ^Level

update :: proc(input : Input) {
  if input.close_window/* || input.esc_press*/ {
    is_running = false
    return
  }

  if splash_screen {
    if input.enter_press || input.esc_press {
      splash_screen = false
    }
    return
  }

  if input.left_press {
    entity_press_dir_all(.Left)
  }
  if input.right_press {
    entity_press_dir_all(.Right)
  }
  if input.up_press {
    entity_press_dir_all(.Up)
  }
  if input.down_press {
    entity_press_dir_all(.Down)
  }
  if input.reset_press {
    entity_reset_all()
    history_current = 0
    button_state = {}
    entity_update_passive_state_all()
  }
  if input.undo_press {
    if history_current > 0 {
      history_current -= 1
      entity_undo_all(history[history_current])
      button_state = {}
      entity_update_passive_state_all()
    }
  }
  if input.redo_press {
    if history_current < history_len {
      entity_redo_all(history[history_current])
      history_current += 1
      button_state = {}
      entity_update_passive_state_all()
    }
  }

  half_life_interp :: proc(half_life, delta_time : f32) -> f32 {
    return 1 - math.pow(0.5, delta_time / half_life)
  }
  camera_pos = linalg.lerp(camera_pos, camera_target, half_life_interp(0.25, f32(input.delta_time)))
  if queued_level_unload.level_data != nil {
    if linalg.vector_length2(camera_pos - camera_target) < 0.1 {
      unload_level(queued_level_unload)
      queued_level_unload = {}
    }
  }

  switch animation {
    case .None:
    case .Move:
      animation_timer += 10 * f32(input.delta_time)
    case .Invalid:
      animation_timer += 20 * f32(input.delta_time)
  }
  if animation != .None {
    if animation_timer > 1 {
      animation_timer = 1
    }
    entity_update_animation_all(animation, animation_timer)
    if animation_timer == 1 {
      animation = .None
    }
  }
}

load_level :: proc(level : ^Level) -> (result : LoadedLevel) {
  if queued_level_unload.level_data != nil {
    camera_pos = camera_target
    unload_level(queued_level_unload)
    queued_level_unload = {}
  }

  result.level_data = level
  result.loaded_entities = make([dynamic]EntityHandle)
  for _, entity in level.entities {
    append(&result.loaded_entities, new_entity(entity))
  }
  return
}

unload_level :: proc(level : LoadedLevel) {
  for entity in level.loaded_entities {
    delete_entity(entity_lookup[entity])
  }
  delete(level.loaded_entities)
  entity_update_passive_state_all()
}

draw :: proc() {
  graphics.clear_target({ .Color, .Depth })

  if splash_screen {
    material := graphics.MaterialSprite{
      spritesheet = get_texture(.Tileset),
      rect = START_SCREEN_GFX_RECT,
      blend_mode = .Opaque,
      color = { 1, 1, 1, 1 },
      render_order = 1,
      sorting = .None,
      flags = {},
      alpha_clip = 0,
    }
    graphics.set_camera_matrix(1)
    graphics.queue_draw_mesh(meshes.quad, material, linalg.matrix4_scale_f32({ ROOM_WIDTH, ROOM_HEIGHT, 1}))
    graphics.flush_queue()
    return
  }

  graphics.set_camera_matrix(linalg.matrix4_translate_f32(camera_pos))

  for layer in current_level.tile_layers {
    switch layer in layer {
       case TileLayer:
        graphics.queue_draw_mesh(meshes.quad, layer.material, linalg.matrix4_translate_f32({ f32(current_level.x) + f32(ROOM_WIDTH-1)/2, f32(current_level.y) + f32(ROOM_HEIGHT-1)/2, 0 }) * linalg.matrix4_scale_f32({ ROOM_WIDTH, ROOM_HEIGHT, 1}))
    }
  }

  if queued_level_unload.level_data != nil {
    for layer in queued_level_unload.level_data.tile_layers {
      switch layer in layer {
         case TileLayer:
          graphics.queue_draw_mesh(meshes.quad, layer.material, linalg.matrix4_translate_f32({ f32(queued_level_unload.level_data.x) + f32(ROOM_WIDTH-1)/2, f32(queued_level_unload.level_data.y) + f32(ROOM_HEIGHT-1)/2, 0 }) * linalg.matrix4_scale_f32({ ROOM_WIDTH, ROOM_HEIGHT, 1}))
      }
    }
  }

  entity_draw_all(current_level.entity_material)

  /*
  SOLID_WHITE ::  graphics.MaterialUnlit{ nil, .Opaque, { 1, 1, 1, 1 }, graphics.RENDER_ORDER_OPAQUE, .None, {}, 0 }
  graphics.queue_draw_mesh(inner_tri, SOLID_WHITE, linalg.matrix4_translate_f32({ 0, 0, -0.25}))
  */

  graphics.flush_queue()
}

display_resize :: proc(width, height : int) {
  aspect := f32(width) / f32(height)
  MIN_ASPECT :: f32(ROOM_WIDTH) / f32(ROOM_HEIGHT)
  half_width := f32(ROOM_WIDTH)/2
  half_height := f32(ROOM_HEIGHT)/2
  if aspect > MIN_ASPECT {
    half_width = half_height * aspect
  } else {
    half_height = half_width / aspect
  }
  half_width *= CAMERA_SCALE
  half_height *= CAMERA_SCALE
  graphics.set_projection_matrix(linalg.matrix_ortho3d_f32(-half_width, half_width, -half_height, half_height, 0, 100, true))
}

find_current_room :: proc() {
  dragon := entity_lookup[dragon].(EntityDragon)
  room_coords := world_get_room_coords(dragon._tile_pos)
  if new_level, ok := world.level_by_grid[room_coords]; ok {
    if last_level != new_level {
      if last_level != nil {
        history_current = -1
      }
      old_level := current_level
      current_level = load_level(new_level)
      queued_level_unload = old_level
      last_level = current_level.level_data
      camera_target = { f32(current_level.x) + f32(ROOM_WIDTH-1)/2, f32(current_level.y) + f32(ROOM_HEIGHT-1)/2, 0 }
    }
  }
}
