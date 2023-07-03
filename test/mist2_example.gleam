import mist2 as mist
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bit_builder.{BitBuilder}
import gleam/otp/actor

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
