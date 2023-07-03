import mist2.{Closed, Connection, Custom, Frame, Shutdown} as mist
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bit_builder
import gleam/otp/actor
import gleam/erlang/process
import gleam/result

// === Regular HTTP ===

fn service(_request: Request(BitString)) -> Response(mist.ResponseData) {
  response.new(200)
  |> response.set_header("content-type", "text/plain")
  |> response.set_body("Hello, Joe!")
  |> response.map(bit_builder.from_string)
  |> response.map(mist.Bytes)
}

pub fn main_plain_service() {
  mist.new(service)
  |> mist.read_request_body(bytes_limit: 1024 * 1024 * 10)
  |> mist.port(8080)
  |> mist.start_http()
}

// === Websockets ===

pub type MyMessage {
  // Let's say we're subscribing to some pubsub topic
  Broadcast(String)
}

fn handle_ws_message(state, conn, message) {
  case message {
    Frame(<<"ping":utf8>>) -> {
      mist.send_frame(conn, <<"pong":utf8>>)
      actor.Continue(state)
    }
    Frame(_) -> {
      actor.Continue(state)
    }
    Custom(Broadcast(text)) -> {
      mist.send_frame(conn, <<text:utf8>>)
      actor.Continue(state)
    }
    Closed | Shutdown -> actor.Stop(process.Normal)
  }
}

pub fn main_websockets() {
  // This would be the selector for the hypothetic pubsub system messages
  let selector = process.new_selector()
  let state = Nil

  let service = fn(request: Request(Connection)) -> Response(mist.ResponseData) {
    case request.path {
      "/ws" ->
        mist.websocket(request)
        |> mist.with_state(state)
        |> mist.selecting(selector)
        |> mist.on_message(handle_ws_message)
        |> mist.upgrade

      _ -> {
        mist.read_body(request, 1024 * 1024 * 10)
        |> result.lazy_unwrap(fn() { request.set_body(request, <<>>) })
        |> service
      }
    }
  }

  mist.new(service)
  |> mist.port(8080)
  |> mist.start_http
}
