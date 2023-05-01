package game

import "core:math/linalg"

V2 :: linalg.Vector2f32
V3 :: linalg.Vector3f32

ROOM_WIDTH :: 12
ROOM_HEIGHT :: 9

TilePos :: distinct [2]int

Direction :: enum {
  None,
  Up,
  Down,
  Left,
  Right,
}

direction_offsets := [Direction]V3 {
  .None = { 0, 0, 0 },
  .Up = { 0, 1, 0 },
  .Down = { 0, -1, 0 },
  .Left = { -1, 0, 0 },
  .Right = { 1, 0, 0 },
}

direction_tile_offset := [Direction]TilePos {
  .None = { 0, 0 },
  .Up = { 0, 1 },
  .Down = { 0, -1 },
  .Left = { -1, 0 },
  .Right = { 1, 0 },
}

direction_cw_direction := [Direction]Direction {
  .None = .None,
  .Up = .Right,
  .Down = .Left,
  .Left = .Up,
  .Right = .Down,
}

direction_ccw_direction := [Direction]Direction {
  .None = .None,
  .Up = .Left,
  .Down = .Right,
  .Left = .Down,
  .Right = .Up,
}

direction_back_direction := [Direction]Direction {
  .None = .None,
  .Up = .Down,
  .Down = .Up,
  .Left = .Right,
  .Right = .Left,
}

direction_from_string := map[string]Direction {
  "None" = .None,
  "Up" = .Up,
  "Down" = .Down,
  "Left" = .Left,
  "Right" = .Right,
}
