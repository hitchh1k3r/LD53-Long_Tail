package game

Tile :: enum {
  None = 0,
  Floor,
  Wall,
  Hot,
}

@(tile_message=get_collision)
tile_generic_get_collision :: proc(tile : Tile, tile_pos : TilePos) -> (result : CollisionResult) {
  switch tile {
    case .None:
      return {}
    case .Floor:
      return { .Support }
    case .Wall:
      return { .Solid }
    case .Hot:
      return { .Support }
  }
  return {}
}
