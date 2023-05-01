package wasm_mem

import "core:mem"

// Configuration ///////////////////////////////////////////////////////////////////////////////////

  WASM_PAGE_COUNT :: NumPages.MB_512

  SCRATCH_SIZE :: 4 * mem.Megabyte

////////////////////////////////////////////////////////////////////////////////////////////////////

  NumPages :: enum u32 {
    KB_64 =      1,
    KB_512 =     8,
    MB_1 =      16,
    MB_32 =    512,
    MB_64 =   1024,
    MB_128 =  2048,
    MB_256 =  4096,
    MB_512 =  8192,
    GB_1 =   16384,
  }

  NUM_PAGES_STR :: #sparse [NumPages]string{
    .KB_64 =      "1",
    .KB_512 =     "8",
    .MB_1 =      "16",
    .MB_32 =    "512",
    .MB_64 =   "1024",
    .MB_128 =  "2048",
    .MB_256 =  "4096",
    .MB_512 =  "8192",
    .GB_1 =   "16384",
  }

  MEM_END :: uintptr(u32(WASM_PAGE_COUNT) * 65536)

  ARENA_SIZE := u32(MEM_END - heap_base())
  ARENA_MEMORY := ([^]u8)(MEM_END - uintptr(ARENA_SIZE))

  STACK_SIZE := u32(heap_base() - data_end())

////////////////////////////////////////////////////////////////////////////////////////////////////

foreign import "env"

@(default_calling_convention="contextless")
foreign env {

  data_end :: proc() -> uintptr ---
  heap_base :: proc() -> uintptr ---

}