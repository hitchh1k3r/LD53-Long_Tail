package yeard

import "core:fmt"

_PROFILE_START := proc(name : string, args := "", location := #caller_location) {}
_PROFILE_END := proc() {}

@(deferred_none=PROFILE_END)
PROFILE :: proc(name : string, args := "", location := #caller_location) {
  PROFILE_START(fmt.tprint(args = { "beard.", name }, sep = ""), args, location)
}

PROFILE_START :: proc(name : string, args := "", location := #caller_location) {
  _PROFILE_START(name, args, location)
}
PROFILE_END :: proc() {
  _PROFILE_END()
}
