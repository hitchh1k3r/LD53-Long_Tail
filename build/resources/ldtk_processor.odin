package meta_resources

import "core:image/png"
import "core:fmt"
import "core:os"
import "core:mem"

load_ldtk :: proc(bytes : []u8) -> []u8 {
  PROFILE(#procedure)
  return bytes
}
