package shared

import "core:fmt"

host_to_string :: proc(address: u32) -> string {
  parts := transmute([4]byte)address
  return fmt.tprintf("%v.%v.%v.%v", parts[0], parts[1], parts[2], parts[3])
}
