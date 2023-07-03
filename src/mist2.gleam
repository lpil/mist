//// A sketch of a new API design for Mist.
//// 
//// The goal for this API is to hide as much as the complexities of serving
//// HTTP from the user as possible, exposing only the simplest possible API.

import gleam/bit_builder.{BitBuilder}
import gleam/iterator.{Iterator}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/erlang/process.{Subject}
import gleam/int
import gleam/io
import glisten

//
// === Working with requests ===
//

/// A handle to a request that can be used to read the request body.
pub type RequestHandle

/// The error for when the request body cannot be decoded.
/// This could live in a separate public module.
pub type ReadError

pub fn read_body(
  request: Request(RequestHandle),
  max_body_limit _max_body_limit: Int,
) -> Result(Request(BitString), ReadError) {
  request
  |> request.set_body(<<"todo: real impl":utf8>>)
  |> Ok
}

//
// === Creating responses ===
//

/// The type of data that can be sent in a response.
pub type ResponseData {
  // TODO: Work out upgrading to websockets
  // WebSocket
  Bytes(BitBuilder)
  Chunked(Iterator(BitBuilder))
  File(descriptor: FileDescriptor, offset: Int, length: Int)
}

/// An open file which can be sent as a response.
/// This could live in a separate public module.
pub type FileDescriptor

//
// === Starting a web server ===
//

/// A builder used to create a running web server
pub opaque type Builder(request_body, response_body) {
  Builder(
    port: Int,
    handler: fn(Request(request_body)) -> Response(response_body),
    /// A function that is called after the server has started successfully.
    /// This takes just the port here, but likely more information would be
    /// useful such as information on the transport.
    after_start: fn(Int) -> Nil,
  )
}

pub fn new(handler: fn(Request(in)) -> Response(out)) -> Builder(in, out) {
  Builder(
    port: 8000,
    handler: handler,
    after_start: fn(port) {
      let message = "Listening on port localhost:" <> int.to_string(port)
      // Use the OTP logger here rather than io.println
      io.println(message)
    },
  )
}

pub fn with_port(builder: Builder(in, out), port: Int) -> Builder(in, out) {
  Builder(..builder, port: port)
}

pub fn with_binary_body(
  builder: Builder(BitString, out),
  max_body_limit max_body_limit: Int,
) -> Builder(RequestHandle, out) {
  let handler = fn(request) {
    case read_body(request, max_body_limit) {
      Ok(request) -> builder.handler(request)
      Error(_) -> todo as "What should the error behaviour should be?"
    }
  }
  Builder(
    port: builder.port,
    after_start: builder.after_start,
    handler: handler,
  )
}

pub fn after_start(
  builder: Builder(in, out),
  after_start: fn(Int) -> Nil,
) -> Builder(in, out) {
  Builder(..builder, after_start: after_start)
}

// A subject is returned so that the server can be interacted with, and also so
// we can add it to a supervision tree.
pub fn start_http(
  _builder: Builder(RequestHandle, ResponseData),
) -> Result(Subject(ServerMessage), glisten.StartError) {
  todo
}

// A subject is returned so that the server can be interacted with, and also so
// we can add it to a supervision tree.
pub fn start_https(
  _builder: Builder(RequestHandle, ResponseData),
  certfile _certfile: String,
  keyfile _keyfile: String,
) -> Result(Subject(ServerMessage), glisten.StartError) {
  todo
}

//
// === Interactive with a running server ===
//

pub type ServerMessage {
  GracefulShutdown(drain_seconds: Int)
}
