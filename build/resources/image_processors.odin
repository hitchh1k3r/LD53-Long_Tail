package meta_resources

import "core:image/png"
import "core:fmt"
import "core:os"
import "core:mem"

load_png :: proc(bytes : []u8) -> []u8 {
  PROFILE(#procedure)
  img, err := png.load_from_bytes(bytes)
  if err != nil {
    fmt.eprintf("Error loading image file %v\n", err)
    os.exit(1)
  }
  defer png.destroy(img)

  if img.depth == 8 {
    data_size := (img.width * img.height * img.channels)
    result := make([]u8, size_of(i8) + size_of(i32) + size_of(i32) + data_size)
    write := result

    flip_img(img.width, img.height, img.channels, img.pixels.buf[:])

    mem.copy(&write[0], &img.channels, size_of(i8))
    write = write[size_of(i8):]

    mem.copy(&write[0], &img.width, size_of(i32))
    write = write[size_of(i32):]

    mem.copy(&write[0], &img.height, size_of(i32))
    write = write[size_of(i32):]

    mem.copy(&write[0], &img.pixels.buf[0], data_size)

    return result
  } else {
    fmt.eprintf("Wrong image depth %v (should be 8)\n", img.depth)
    os.exit(1)
  }
}

flip_img :: proc(width, height, channels : int, bytes : []u8) {
  PROFILE(#procedure)
  row := make([]u8, channels * width)
  defer delete(row)
  for r in 0..<(height/2) {
    a := &bytes[r * len(row)]
    b := &bytes[(height - r - 1) * len(row)]
    mem.copy(&row[0], a, len(row))
    mem.copy(a, b, len(row))
    mem.copy(b, &row[0], len(row))
  }
}
