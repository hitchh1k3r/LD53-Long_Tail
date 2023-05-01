package game

import "core:container/small_array"
import "core:fmt"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

  EntityHandle :: distinct u64

  EntityBase :: struct {
    handle : EntityHandle,
    _tile_pos : TilePos,
    next_entity_at_pos : ^Entity,
  }

// Global State ////////////////////////////////////////////////////////////////////////////////////

  entity_backing : small_array.Small_Array(512, Entity)

  entity_lookup : map[EntityHandle]^Entity

  entity_sas : map[TilePos]^Entity

// Interface ///////////////////////////////////////////////////////////////////////////////////////

  new_entity ::  proc(entity : Entity) -> EntityHandle {
    handle := next_entity_handle()

    small_array.append(&entity_backing, entity)
    entity := &entity_backing.data[entity_backing.len-1]
    entity_base := get_base(entity)
    entity_base.handle = handle
    entity_lookup[handle] = entity
    entity_base.next_entity_at_pos = entity_sas[entity_base._tile_pos]
    entity_sas[entity_base._tile_pos] = entity

    entity_init(entity)

    return handle
  }

  delete_entity :: proc(entity : ^Entity) {
    entity_base := get_base(entity)
    delete_handle := get_base(entity).handle
    delete_key(&entity_lookup, delete_handle)

    // Remove From Pos:
    {
      prev_ll := get_base(entity_sas[entity_base._tile_pos])
      if prev_ll == entity_base {
        entity_sas[entity_base._tile_pos] = entity_base.next_entity_at_pos
      } else {
        for prev_ll != nil && prev_ll.next_entity_at_pos != entity {
          prev_ll = get_base(prev_ll.next_entity_at_pos)
        }
        if prev_ll != nil {
          prev_ll.next_entity_at_pos = entity_base.next_entity_at_pos
        } else {
          assert(false, fmt.tprintf("an entity moved and we could not find it in the Linked List for it's old position: %v", entity))
        }
      }
    }

    if entity_backing.len > 0 {
      // Update CellPos SAS:
      move_address := &entity_backing.data[entity_backing.len-1]
      move_base := get_base(move_address)
      entity_backing.len -= 1
      if entity != move_address {
        entity^ = move_address^
        prev_ll := get_base(entity_sas[move_base._tile_pos])
        if prev_ll == move_base {
          entity_sas[move_base._tile_pos] = entity
        } else {
          for prev_ll != nil && prev_ll.next_entity_at_pos != move_address {
            prev_ll = get_base(prev_ll.next_entity_at_pos)
          }
          if prev_ll != nil {
            prev_ll.next_entity_at_pos = entity
          } else {
            fmt.eprintf("%v(%v): We could not find the entity we shifted in the SAS, so we will add it now.", #file, #line)
            get_base(entity).next_entity_at_pos = entity_sas[move_base._tile_pos]
            entity_sas[move_base._tile_pos] = entity
          }
        }
        entity_lookup[move_base.handle] = entity
      }
    }
  }

  set_tile_pos :: proc(entity : ^Entity, new_pos : TilePos) {
    entity_base := get_base(entity)
    old_pos := entity_base._tile_pos

    if old_pos != new_pos {
      @(allow_mutation=_tile_pos) _ :: ""
      {
        entity_base._tile_pos = new_pos
      }

      // Remove From Old Pos:
      old_pos_prev_ll := get_base(entity_sas[old_pos])
      if old_pos_prev_ll == entity_base {
        entity_sas[old_pos] = entity_base.next_entity_at_pos
      } else {
        for old_pos_prev_ll != nil && old_pos_prev_ll.next_entity_at_pos != entity {
          old_pos_prev_ll = get_base(old_pos_prev_ll.next_entity_at_pos)
        }
        if old_pos_prev_ll.next_entity_at_pos == entity {
          old_pos_prev_ll.next_entity_at_pos = entity_base.next_entity_at_pos
        } else {
          assert(false, fmt.tprintf("an entity moved and we could not find it in the Linked List for it's old position: %v", entity))
        }
      }
      // Add to new pos:
      entity_base.next_entity_at_pos = entity_sas[new_pos]
      entity_sas[new_pos] = entity
    }
  }

// Internal ////////////////////////////////////////////////////////////////////////////////////////

  @(private="file")
  next_entity_handle :: proc() -> EntityHandle {
    SALT :: u64(0xDEADBEEFDEAD1337)

    @(static) idx : u64
    defer idx += 1

    big := u128(SALT ~ idx)
    big *= 26082833894132791297 // u64: 18446744073709551629 (14 above max(u64))
    big %= 10000000000000000051 // u64: 18446744073709551557 (58 below max(u64))   u32: 4294967291 (4 below max(u32))
    return EntityHandle(big)
  }
