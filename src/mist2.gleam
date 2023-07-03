//// A sketch of a new API design for Mist.
//// 
//// The goal for this API is to hide as much as the complexities of serving
//// HTTP from the user as possible, exposing only the simplest possible API.

import gleam/bit_builder.{BitBuilder}
import gleam/iterator.{Iterator}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/erlang/process.{Subject}
import gleam/otp/actor
import gleam/option.{None, Option, Some}
import gleam/int
import gleam/io
import glisten

//
// === Working with requests ===
//

/// A handle to a request that can be used to read the request body.
pub type Connection

/// The error for when the request body cannot be decoded.
/// This could live in a separate public module.
pub type ReadError

pub fn read_body(
  request: Request(Connection),
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

pub fn port(builder: Builder(in, out), port: Int) -> Builder(in, out) {
  Builder(..builder, port: port)
}

pub fn read_request_body(
  builder: Builder(BitString, out),
  bytes_limit bytes_limit: Int,
) -> Builder(Connection, out) {
  let handler = fn(request) {
    case read_body(request, bytes_limit) {
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
  _builder: Builder(Connection, ResponseData),
) -> Result(Subject(ServerMessage), glisten.StartError) {
  todo
}

// A subject is returned so that the server can be interacted with, and also so
// we can add it to a supervision tree.
pub fn start_https(
  _builder: Builder(Connection, ResponseData),
  certfile _certfile: String,
  keyfile _keyfile: String,
) -> Result(Subject(ServerMessage), glisten.StartError) {
  todo
}

//
// === Websockets ===
//

pub type WebsocketConnection

pub type WebsocketMessage(custom) {
  /// New message from the client
  Frame(BitString)
  /// Client disconnected
  Closed
  /// Server is shutting down
  Shutdown
  /// A custom message from another process
  Custom(custom)
}

pub opaque type WebSocketBuilder(state, message) {
  WebSocketBuilder(
    request: Request(Connection),
    state: state,
    handler: fn(state, WebsocketConnection, WebsocketMessage(message)) ->
      actor.Next(state),
    selector: Option(process.Selector(message)),
  )
}

pub fn websocket(request: Request(Connection)) -> WebSocketBuilder(Nil, any) {
  WebSocketBuilder(
    request: request,
    state: Nil,
    handler: fn(_, _, _) { actor.Stop(process.Normal) },
    selector: None,
  )
}

pub fn selecting(
  builder: WebSocketBuilder(state, message),
  selector: process.Selector(message),
) -> WebSocketBuilder(state, message) {
  WebSocketBuilder(
    builder.request,
    builder.state,
    builder.handler,
    Some(selector),
  )
}

pub fn with_state(
  builder: WebSocketBuilder(state, any),
  state: state,
) -> WebSocketBuilder(state, any) {
  WebSocketBuilder(builder.request, state, builder.handler, builder.selector)
}

pub fn on_message(
  builder: WebSocketBuilder(state, message),
  handler: fn(state, WebsocketConnection, WebsocketMessage(message)) ->
    actor.Next(state),
) -> WebSocketBuilder(state, message) {
  WebSocketBuilder(builder.request, builder.state, handler, builder.selector)
}

// This should return an error?
pub fn send_frame(connection: WebsocketConnection, frame: BitString) -> Nil {
  todo
}

// This never returns
pub fn upgrade(builder: WebSocketBuilder(state, message)) -> Response(anything) {
  todo
}

//
// === Interactive with a running server ===
//

pub type ServerMessage {
  GracefulShutdown(drain_seconds: Int)
}
