package server

// https://www.youtube.com/watch?v=FxrKS_1zE9s

import "core:log"
import "core:fmt"
import enet "vendor:ENet"
import utils "../."

main :: proc() {
  context.logger = log.create_console_logger()
  if enet.initialize() > 0 {
    log.error("Failed to initialize enet")
    return
  }
  defer enet.deinitialize()

  address := enet.Address {
    host = enet.HOST_ANY,
    port = 8080,
  }

  server := enet.host_create(&address, 32, 1, 0, 0)
  if server == nil {
    log.error("error ocurred while initializing server")
    return
  }
  defer enet.host_destroy(server)


  // APPLICATION LOOP {{{
  for {
    event : enet.Event
    for enet.host_service(server, &event, 1000) > 0 {
      #partial switch event.type {
      case .CONNECT: {
        log.infof(
          "client %v:%v connected", 
          utils.host_to_string(event.peer.address.host),
          event.peer.address.port,
        )
      }
      case .RECEIVE: {
        log.infof(
          "a packet of length %v containing %s was received from %v:%v",
          event.packet.dataLength,
          event.packet.data,
          utils.host_to_string(event.peer.address.host),
          event.peer.address.port,
        )
      }
      case .DISCONNECT: {
        log.infof(
          "client %v:%v disconnected", 
          utils.host_to_string(event.peer.address.host),
          event.peer.address.port,
        )
      }
      }
    }
  }
  // }}} APPLICATION LOOP


}
