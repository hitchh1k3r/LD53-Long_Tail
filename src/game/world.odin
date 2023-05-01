package game

world_get_room_coords :: proc(tile_pos : TilePos) -> [2]int {
  room_coords := [2]int{ tile_pos.x / ROOM_WIDTH, tile_pos.y / ROOM_HEIGHT }
  if tile_pos.x < 0 {
    room_coords.x -= 1
  }
  if tile_pos.y < 0 {
    room_coords.y -= 1
  }
  return room_coords
}

world_get_tile_at :: proc(tile_pos : TilePos) -> Tile {
  room_coords := world_get_room_coords(tile_pos)
  if level, ok := world.level_by_grid[room_coords]; ok {
    return level.tiles[tile_pos.y - room_coords.y*ROOM_HEIGHT][tile_pos.x - room_coords.x*ROOM_WIDTH]
  }
  return .None
}

CollisionFlag :: enum {
  Support,       // The move is allowed
  Solid,         // An allowed move is blocked
  Cancel_Solid,  // Cancel blocking an allowed move (it's allowed again)
  Force_Support, // Allow a move, it cannot be blocked
  Force_Solid,   // This move is never allowed (even if it cannot be blocked)
}
CollisionResult :: bit_set[CollisionFlag]

world_can_move_to :: proc(entity : ^Entity, target_tile_pos : TilePos, move_dir : Direction) -> bool {
  when NO_CLIP {
    if get_base(entity).handle == dragon {
      return true
    }
  }

  result : CollisionResult

  room_coords := world_get_room_coords(target_tile_pos-direction_tile_offset[move_dir])
  room_min_x := room_coords.x * ROOM_WIDTH
  room_min_y := room_coords.y * ROOM_HEIGHT
  if target_tile_pos.x < room_min_x || target_tile_pos.x >= room_min_x+ROOM_WIDTH ||
     target_tile_pos.y < room_min_y || target_tile_pos.y >= room_min_y+ROOM_HEIGHT {
    result |= { .Solid }
  }

  if move_dir != .None {
    result |= world_get_exit_collision(target_tile_pos-direction_tile_offset[move_dir], entity, move_dir)
  }
  result |= world_get_collision(target_tile_pos, move_dir, entity)
  result |= get_dragon_collision(&entity_lookup[dragon].(EntityDragon), target_tile_pos, entity, move_dir)

  if .Force_Solid in result {
    return false
  }
  if .Force_Support in result {
    return true
  }
  if .Support not_in result {
    return false
  }
  if result & { .Solid, .Cancel_Solid } == { .Solid } {
    return false
  }
  return true
}
