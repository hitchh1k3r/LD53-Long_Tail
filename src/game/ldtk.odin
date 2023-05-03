package game

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:strings"

import "project:graphics"
import "project:platform"

world : World

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  DoorLink :: struct {
    pos : TilePos,
    dir : Direction,
    flip : bool,
  }

  World :: struct {
    level_by_iid : map[string]^Level,
    level_by_grid : map[[2]int]^Level,
    levels : []Level,
    doorways : map[string]DoorLink,
    string_intern : strings.Intern,
  }

  Level :: struct {
    iid : string,
    x, y : int,
    width, height : int,

    tiles : [][]Tile,

    entities : map[string]Entity,
    entity_material : graphics.MaterialSprite,

    tile_layers : []LevelLayer,
  }

  LevelLayer :: union { TileLayer }

  TileLayer :: struct {
    material : graphics.MaterialTilemap,
  }

// Configuration ///////////////////////////////////////////////////////////////////////////////////

  GRID_SIZE :: 16

// Interface ///////////////////////////////////////////////////////////////////////////////////////

  load_world :: proc() {
    ok : bool
    if world, ok = load_ldtk_world(.World); ok {
    } else {
      // TODO (hitch) 2023-03-25 PANIC
    }
  }

// Internal ////////////////////////////////////////////////////////////////////////////////////////

  load_int_layer :: proc(layer_name : string, ints : []int, layer_index : int, level : ^Level) -> LevelLayer {
    switch layer_name {
      case "Tiles":
        tile_lookup := map[int]Tile{
          0 = .None,
          1 = .Floor,
          2 = .Wall,
          3 = .Hot,
        }
        defer delete(tile_lookup)
        idx := 0
        for r in 1..=level.height {
          for c in 0..<level.width {
            if tile, ok := tile_lookup[ints[idx]]; ok {
              level.tiles[level.height-r][c] = tile
            } else {
              // TODO (hitch) 2023-03-25 PANIC
            }
            idx += 1
          }
        }
      case:
        // TODO (hitch) 2023-03-25 PANIC
    }

    return nil
  }

  load_auto_layer :: proc(layer_name : string, tileset : platform.ResourceImage, tiles : []LoadingTileSprite, layer_index : int, level : ^Level) -> LevelLayer {
    return load_tile_layer(layer_name, tileset, tiles, layer_index, level)
  }


  load_tile_layer :: proc(layer_name : string, tileset : platform.ResourceImage, tiles : []LoadingTileSprite, layer_index : int, level : ^Level) -> LevelLayer {
    tile_layer : TileLayer

    tilemap := make([]u32, level.width * level.height)
    defer delete(tilemap)
    for tile in tiles {
      tilemap[(tile.px.x / GRID_SIZE) + (level.width * (tile.px.y / GRID_SIZE))] = u32(tile.tile + 1)
    }

    if tile_buffer, ok := graphics.create_buffer_texture(mem.slice_data_cast([]u8, tilemap), .UINT_1_32); ok {
      tile_layer.material = graphics.MaterialTilemap{ get_texture(tileset), tile_buffer, .Alpha_Blend, graphics.RENDER_ORDER_OPAQUE + 100 + 5 * graphics.RenderOrder(layer_index), .None, { .Disable_Z_Write }, 0 }
    }

    if layer_name == "Terrain_Base" {
      tile_layer.material.blend_mode = .Opaque
    }

    return tile_layer
  }

  load_entity_layer :: proc(layer_name : string, entities : []LoadingEntity, layer_index : int, world : ^World, level : ^Level) -> LevelLayer {
    switch layer_name {
      case "Entities":
        level.entity_material = graphics.MaterialSprite{ nil, {}, .Alpha_Blend, { 1, 1, 1, 1 }, graphics.RENDER_ORDER_OPAQUE + 100 - 2 + 5 * graphics.RenderOrder(layer_index), .None, { .Disable_Z_Write }, 0 }
        for entity in entities {
          switch entity.type {
            case "Enterance":
              link := DoorLink{ TilePos(entity.pos), direction_from_string[entity.fields["Direction"].(string)], entity.fields["Flip_Dragon"].(bool) or_else false }
              if entity.fields["Game_Start"].(bool) or_else false {
                dragon := (&entity_lookup[dragon].(EntityDragon))
                set_dragon_reset(dragon, link.pos, link.dir, link.flip)
              }
              iid, _ := strings.intern_get(&world.string_intern, entity.iid)
              world.doorways[iid] = link
              level.entities[iid] = EntityDoorway{ base = { _tile_pos = TilePos(entity.pos) },
                                                       facing = link.dir,
                                                       linked_door = (strings.intern_get(&world.string_intern, entity.fields["Target"].(string) or_else "") or_else "") }
            case "Egg":
              // entity.fields["Type"].(string) // Hot, Cold
              iid, _ := strings.intern_get(&world.string_intern, entity.iid)
              level.entities[iid] = EntityEgg{ base = { _tile_pos = TilePos(entity.pos) }, iid = iid }
            case "Gate_Eggs":
              iid, _ := strings.intern_get(&world.string_intern, entity.iid)
              level.entities[iid] = EntityEggGate{ base = { _tile_pos = TilePos(entity.pos) }, egg_count = int(entity.fields["Whelps_Required"].(f64)) }
            case "Gate_Button":
              iid, _ := strings.intern_get(&world.string_intern, entity.iid)
              channel : ButtonChannel
              switch entity.fields["Button_Channel"].(string) or_else "Channel_1" {
                case "Channel_1":
                  channel = .CH_1
                case "Channel_2":
                  channel = .CH_2
                case "Channel_3":
                  channel = .CH_3
                case "Channel_4":
                  channel = .CH_4
              }
              level.entities[iid] = EntityButtonGate{ base = { _tile_pos = TilePos(entity.pos) }, channel = channel }
            case "Button":
              iid, _ := strings.intern_get(&world.string_intern, entity.iid)
              channel : ButtonChannel
              switch entity.fields["Button_Channel"].(string) or_else "Channel_1" {
                case "Channel_1":
                  channel = .CH_1
                case "Channel_2":
                  channel = .CH_2
                case "Channel_3":
                  channel = .CH_3
                case "Channel_4":
                  channel = .CH_4
              }
              level.entities[iid] = EntityButton{ base = { _tile_pos = TilePos(entity.pos) }, channel = channel }
          }
        }
      case:
        // TODO (hitch) 2023-03-25 PANIC
    }

    return nil
  }

  @(private="file")
  LoadingTileSprite :: struct {
    px : [2]int,
    tile : int,
  }

  @(private="file")
  LoadingEntity :: struct {
    iid : string,
    type : string,
    pos : [2]int,
    fields : map[string]LoadingField,
  }

  @(private="file")
  LoadingField :: union {
    bool,
    string,
    f64,
  }

  load_ldtk_world :: proc(file : platform.ResourceLevel) -> (world : World, ok : bool) {
    using world
    strings.intern_init(&string_intern)

    texture_lookup := map[string]platform.ResourceImage {
      "tileset.png" = .Tileset,
    }

    if world_json_bytes, file_ok := platform.load_resource(file); file_ok {
      defer platform.free_resource(world_json_bytes)
      arena_backing_data := make([]u8, 64 * mem.Megabyte)
      defer delete(arena_backing_data)
      arena : mem.Arena
      mem.arena_init(&arena, arena_backing_data)
      world_json_parser := json.make_parser(data = world_json_bytes, allocator = mem.arena_allocator(&arena))
      world_json_obj, err := json.parse_object(&world_json_parser)
      if err == nil {
        levels_json := world_json_obj.(json.Object)["levels"].(json.Array)
        levels = make([]Level, len(levels_json))
        for level_json, level_idx in levels_json {
          level := level_json.(json.Object)

          new_level := &levels[level_idx]
          new_level.iid = strings.clone(level["iid"].(json.String))
          level_by_iid[new_level.iid] = new_level

          level_name := level["identifier"].(json.String)
          new_level.x = int(level["worldX"].(json.Float))/GRID_SIZE
          new_level.y = -int(level["worldY"].(json.Float))/GRID_SIZE
          level_by_grid[{ new_level.x/ROOM_WIDTH, new_level.y/ROOM_HEIGHT }] = new_level
          new_level.width = int(level["pxWid"].(json.Float))/GRID_SIZE
          new_level.height = int(level["pxHei"].(json.Float))/GRID_SIZE
          new_level.tiles = make([][]Tile, new_level.height)
          for r in 0..<new_level.height {
            new_level.tiles[r] = make([]Tile, new_level.width)
          }

          layers_json := level["layerInstances"].(json.Array)
          new_level.tile_layers = make([]LevelLayer, len(layers_json))

          layer_idx := 0
          for layer_read := len(layers_json)-1; layer_read >= 0; layer_read -= 1 {
            layer := layers_json[layer_read].(json.Object)
            layer_name := layer["__identifier"].(json.String)
            layer_tiles : json.Array
            switch layer["__type"].(json.String) {
              case "Entities":
                layer_entities := layer["entityInstances"].(json.Array)
                entities := make([]LoadingEntity, len(layer_entities))
                defer {
                  for entity in entities {
                    delete(entity.fields)
                  }
                  delete(entities)
                }
                for entity, idx in layer_entities {
                  entity := entity.(json.Object)
                  grid := entity["__grid"].(json.Array)
                  entities[idx] = {
                    iid = entity["iid"].(json.String),
                    type = entity["__identifier"].(json.String),
                    pos = { int(grid[0].(json.Float))+new_level.x, ROOM_HEIGHT-int(grid[1].(json.Float))+new_level.y-1 },
                    fields = make(map[string]LoadingField),
                  }
                  entity_fields := entity["fieldInstances"].(json.Array)
                  for field in entity_fields {
                    field := field.(json.Object)
                    vals := field["realEditorValues"].(json.Array)
                    if len(vals) > 0 {
                      if obj, ok := vals[0].(json.Object); ok {
                        #partial switch param in obj["params"].(json.Array)[0] {
                          case json.String:
                            entities[idx].fields[field["__identifier"].(json.String)] = param
                          case json.Boolean:
                            entities[idx].fields[field["__identifier"].(json.String)] = param
                          case json.Float:
                            entities[idx].fields[field["__identifier"].(json.String)] = param
                        }
                      }
                    }
                  }
                }
                add_layer := load_entity_layer(layer_name, entities, layer_idx, &world, new_level)
                if add_layer != nil {
                  new_level.tile_layers[layer_idx] = add_layer
                  layer_idx += 1
                }

              case "IntGrid":
                layer_ints := layer["intGridCsv"].(json.Array)
                ints := make([]int, len(layer_ints))
                defer delete(ints)
                for num, idx in layer_ints {
                  ints[idx] = int(num.(json.Float))
                }
                add_layer := load_int_layer(layer_name, ints, layer_idx, new_level)
                if add_layer != nil {
                  new_level.tile_layers[layer_idx] = add_layer
                  layer_idx += 1
                }

              case "AutoLayer":
                layer_tiles = layer["autoLayerTiles"].(json.Array)
                layer_tileset := layer["__tilesetRelPath"].(json.String)
                tiles := make([]LoadingTileSprite, len(layer_tiles))
                defer delete(tiles)
                for tile_json, idx in layer_tiles {
                  tile := tile_json.(json.Object)
                  px := tile["px"].(json.Array)
                  tiles[idx] = LoadingTileSprite{ { int(px[0].(json.Float)), int(px[1].(json.Float)) }, int(tile["t"].(json.Float)) }
                }
                add_layer := load_auto_layer(layer_name, texture_lookup[layer_tileset], tiles, layer_idx, new_level)
                if add_layer != nil {
                  new_level.tile_layers[layer_idx] = add_layer
                  layer_idx += 1
                }

              case "Tiles":
                layer_tiles = layer["gridTiles"].(json.Array)
                layer_tileset := layer["__tilesetRelPath"].(json.String)
                tiles := make([]LoadingTileSprite, len(layer_tiles))
                defer delete(tiles)
                for tile_json, idx in layer_tiles {
                  tile := tile_json.(json.Object)
                  px := tile["px"].(json.Array)
                  tiles[idx] = LoadingTileSprite{ { int(px[0].(json.Float)), int(px[1].(json.Float)) }, int(tile["t"].(json.Float)) }
                }
                add_layer := load_tile_layer(layer_name, texture_lookup[layer_tileset], tiles, layer_idx, new_level)
                if add_layer != nil {
                  new_level.tile_layers[layer_idx] = add_layer
                  layer_idx += 1
                }
            }
          }
          new_level.tile_layers = new_level.tile_layers[:layer_idx]
        }
      } else {
        fmt.eprintf("JSON ERR: %v\n", err)
      }
    } else {
      fmt.eprintln("could not load json")
    }

    ok = true
    return
  }

  delete_str :: proc(str : string) {
    delete(str)
  }
