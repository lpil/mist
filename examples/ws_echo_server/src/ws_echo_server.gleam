import gleam/bit_string
import gleam/erlang
import gleam/erlang/charlist.{Charlist}
import gleam/list
import gleam/otp/actor
import gleam/otp/process
import gleam/result
import mist/tcp.{
  LoopFn, ReceiveMessage, Socket, TcpClosed, listen, send, start_acceptor_pool,
}
import ws_echo_server/mist/http.{parse_request, to_string}
import ws_echo_server/mist/websocket.{
  echo_handler, upgrade_socket, websocket_handler,
}

pub fn main() {
  try listener =
    listen(8080, [])
    |> result.replace_error("failed to listen")
  try _ =
    start_acceptor_pool(
      listener,
      websocket_handler(echo_handler),
      new_state(),
      10,
    )
    |> result.replace_error("oops")

  erlang.sleep_forever()

  Ok(Nil)
}