package client

// https://www.youtube.com/watch?v=FxrKS_1zE9s

import "core:log"
import "core:fmt"
import "core:strings"
import "core:c/libc"
import enet "vendor:ENet"
import rl "vendor:raylib"
import utils "../."

username :: #config(USERNAME, "user")

// TODO: add from & to?
Message :: struct {
  username: string,
  content: string
}

send_message :: proc(peer: ^enet.Peer, message: Message) {
  log.infof(
    "sending to %v:%v message `%v`",
    utils.host_to_string(peer.address.host),
    peer.address.port,
    message.content,
  )

  data := fmt.ctprintf("%v:%v", message.username, message.content)
  packet := enet.packet_create(
    rawptr(data),
    len(data),
    {.RELIABLE},
  )

  enet.peer_send(peer, 0, packet)
}

main :: proc() {
  context.logger = log.create_console_logger()
  if enet.initialize() > 0 {
    log.error("Failed to initialize enet")
    return
  }
  defer enet.deinitialize()

  client := enet.host_create(nil, 1, 1, 0, 0)
  if client == nil {
    log.error("error ocurred while initializing client")
  }

  address : enet.Address
  enet.address_set_host(&address, "127.0.0.1")
  address.port = 8080

  peer := enet.host_connect(client, &address, 1, 0)
  if peer == nil {
    log.error("no available peers for initializing connection")
    return
  }

  event : enet.Event
  // NOTE: tentando conectar até conseguir
  for {
    if enet.host_service(client, &event, 3000) > 0 && event.type == .CONNECT {
      log.infof("connection to %v:%v succeded", utils.host_to_string(peer.address.host), peer.address.port)
      break
    } else {
      enet.peer_reset(peer)
      peer = enet.host_connect(client, &address, 1, 0)
      log.errorf("connection to %v:%v failed", utils.host_to_string(peer.address.host), peer.address.port)
    }
  }

  rl.InitWindow(640, 360, "chat")
  defer rl.CloseWindow()

  // APPLICATION LOOP {{{

  message : []u8 = make([]u8, 50)
  message_edit_mode := true
  message_scroll_index : i32

  // TODO:
  // - adicionar mensagens à lista
  // - saber de qual cliente são
  // - enviar a mensagem
  messages := [dynamic]Message {
    { username = username, content = "oi"},
    { username = username, content = "opa"},
    { username = username, content = "blz?"},
    { username = username, content = "blz" },
  }

  rl.GuiSetStyle(.DEFAULT, transmute(rl.GuiStyleProp)u64(rl.GuiDefaultProperty.TEXT_SIZE), 20)
  rl.SetTargetFPS(60)
  for !rl.WindowShouldClose() {
    // enet part {{{
    for enet.host_service(client, &event, 0) > 0 {
      #partial switch event.type {
      case .RECEIVE: {
        log.infof(
          "a packet of length %u containing %s was received from %v:%v",
          event.packet.dataLength,
          event.packet.data,
          utils.host_to_string(event.peer.address.host),
          event.peer.address.port,
        )
      }
      }
    }
    //}}}

    rl.BeginDrawing()
    {
      rl.ClearBackground(rl.WHITE)
      can_send := draw_chat_screen(message, messages[:], &message_scroll_index, &message_edit_mode)
      if can_send {
        message_str : string = string(message)

        m := Message { 
          username = username,
          content  = strings.clone(message_str),
        }

        append(&messages, m)
        send_message(peer, m)

        for &c in message do c = 0
      }
    }
    rl.EndDrawing()
  }
  // }}} APPLICATION LOOP


  enet.peer_disconnect(peer, 0)
  // INFO: pra q msm isso?
  for enet.host_service(client, &event, 0) > 0 {
    #partial switch event.type {
    case .RECEIVE: {
      enet.packet_destroy(event.packet)
    }
    case .DISCONNECT: {
      log.info("Disconnected")
    }
    }
  }
}

draw_chat_screen :: proc(message: []u8, messages: []Message, scroll_index: ^i32, message_edit_mode: ^bool) -> (ok: bool) {

  window_size : [2]f32 = {
    f32(rl.GetRenderWidth()),
    f32(rl.GetRenderHeight())
  }
  // historico de mensagens {{{
  display_messages := make([]cstring, len(messages), allocator = context.temp_allocator)
  for m, idx in messages {
    using m
    display_messages[idx] = fmt.ctprintf(
      "%v: %v",
      username,
      content
    )
  }

  rl.GuiSetStyle(.LISTVIEW, transmute(rl.GuiStyleProp)u64(rl.GuiControlProperty.TEXT_ALIGNMENT), i32(rl.GuiTextAlignment.TEXT_ALIGN_LEFT))
  rl.GuiListViewEx(
    rl.Rectangle{
      0, 0,
      window_size.x,
      window_size.y - 40
    },
    raw_data(display_messages),
    i32(len(display_messages)),
    scroll_index,
    nil,
    nil,
  )
  rl.GuiSetStyle(.LISTVIEW, transmute(rl.GuiStyleProp)u64(rl.GuiControlProperty.TEXT_ALIGNMENT), i32(rl.GuiTextAlignment.TEXT_ALIGN_CENTER))
  // }}}

  // textbox {{{
  cstr_message : cstring = cstring(raw_data(message))
  if rl.GuiTextBox(rl.Rectangle{ window_size.x / 2 - 150 , window_size.y - 40, 300, 40}, cstr_message, i32(len(message) - 1), message_edit_mode^) {
    pressed_enter := rl.IsKeyDown(.ENTER)
    is_valid_message := cstr_message != ""
    can_send := pressed_enter &&  is_valid_message
    message_edit_mode^ = pressed_enter || !(message_edit_mode^)
    
    return can_send
  }
  return
  // }}}
}
