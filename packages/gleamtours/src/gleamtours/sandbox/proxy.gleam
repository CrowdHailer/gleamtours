import conversation
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response, Response}
import gleam/int
import gleam/io
import gleam/javascript as js
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import midas/task as t
import plinth/browser/message
import plinth/browser/service_worker as sw
import plinth/javascript/console
import snag

// Proxy is facade used by client, could be proxy.Sdk could be in client module i.e. proxy.client
pub type Proxy {
  Proxy(service_worker: sw.ServiceWorker, client_id: String)
}

pub type SubscriberMessage {
  ForwardRequest(from: Int, project_id: String, file: Request(BitArray))
  Registered(client_id: String)
}

pub fn json_request(request) {
  let Request(method, headers, body, scheme, host, port, path, query) = request
  json.object([
    #("method", json.string(http.method_to_string(method))),
    #("headers", json_headers(headers)),
    #("body", json.string(bit_array.base64_encode(body, False))),
    #("scheme", json.string(http.scheme_to_string(scheme))),
    #("host", json.string(host)),
    #("port", json.nullable(port, json.int)),
    #("path", json.string(path)),
    #("query", json.nullable(query, json.string)),
  ])
}

fn request_payload(id, project_id, request) {
  let Request(method, headers, body, scheme, host, port, path, query) = request
  use body <- promise.map(conversation.read_bits(body))
  let assert Ok(body) = body
  let request = Request(method, headers, body, scheme, host, port, path, query)
  json.object([
    #(
      "request",
      json.object([
        // id is ref
        #("id", json.int(id)),
        #("project_id", json.string(project_id)),
        #("request", json_request(request)),
      ]),
    ),
  ])
}

fn json_headers(headers) {
  // encoded as tuples
  json.array(headers, fn(h) {
    let #(k, v) = h
    json.array([k, v], json.string)
  })
}

pub fn subscriber_decoder(raw) {
  dynamic.any([
    dynamic.field("registered", dynamic.decode1(Registered, dynamic.string)),
    dynamic.field(
      "request",
      dynamic.decode3(
        ForwardRequest,
        dynamic.field("id", dynamic.int),
        dynamic.field("project_id", dynamic.string),
        dynamic.field("request", request_decoder),
      ),
    ),
  ])(raw)
  |> result.map_error(fn(reason) { snag.new(string.inspect(reason)) })
  |> snag.context("Failed to decode message " <> string.inspect(raw))
}

fn header_decoder(raw) {
  dynamic.list(dynamic.tuple2(dynamic.string, dynamic.string))(raw)
}

fn body_decoder(raw) {
  use encoded <- result.try(dynamic.string(raw))
  bit_array.base64_decode(encoded)
  |> result.replace_error([dynamic.DecodeError("bitarray", encoded, [])])
}

pub fn request_decoder(raw) {
  dynamic.decode8(
    Request,
    dynamic.field("method", http.method_from_dynamic),
    dynamic.field("headers", header_decoder),
    dynamic.field("body", body_decoder),
    dynamic.field("scheme", fn(raw) {
      use str <- result.try(dynamic.string(raw))
      http.scheme_from_string(str)
      |> result.replace_error([dynamic.DecodeError("scheme", str, [])])
    }),
    dynamic.field("host", dynamic.string),
    dynamic.field("port", dynamic.optional(dynamic.int)),
    dynamic.field("path", dynamic.string),
    dynamic.field("query", dynamic.optional(dynamic.string)),
  )(raw)
}

type Message {
  Register
  ForwardedResponse(Int, Result(Response(BitArray), String))
}

pub fn response_decoder(raw) {
  dynamic.decode3(
    Response,
    dynamic.field("status", dynamic.int),
    dynamic.field("headers", header_decoder),
    dynamic.field("body", body_decoder),
  )(raw)
}

fn proxy_decoder(raw: Json) {
  dynamic.any([
    dynamic.field("register", fn(_) { Ok(Register) }),
    dynamic.field(
      "response",
      dynamic.decode2(
        ForwardedResponse,
        dynamic.field("caller", dynamic.int),
        dynamic.any([
          dynamic.decode1(Ok, dynamic.field("ok", response_decoder)),
          dynamic.decode1(Error, dynamic.field("error", dynamic.string)),
        ]),
      ),
    ),
  ])(dynamic.from(raw))
}

fn response_payload(caller_id, response) {
  let reply = case response {
    Ok(Response(status, headers, body)) ->
      json.object([
        #("caller", json.int(caller_id)),
        #(
          "ok",
          json.object([
            #("status", json.int(status)),
            #("headers", json_headers(headers)),
            #("body", json.string(bit_array.base64_encode(body, False))),
          ]),
        ),
      ])
    Error(reason) -> {
      let debug = snag.pretty_print(reason)

      json.object([
        #("caller", json.int(caller_id)),
        #("error", json.string(debug)),
      ])
    }
  }
  json.object([#("response", reply)])
}

pub fn install(on_request) {
  use _registration <- t.await(
    sw.register("/proxy.js") |> t.map_error(snag.new),
  )
  use registration <- promise.await(sw.ready())
  // should always have active service worker after calling ready.
  let assert Ok(worker) = sw.active(registration)
  promise.new(fn(resolve) {
    sw.service_worker_on_message(fn(raw) {
      case subscriber_decoder(dynamic.from(raw)) {
        Ok(Registered(client_id)) -> resolve(Ok(Proxy(worker, client_id)))
        Ok(ForwardRequest(id, project_id, request)) ->
          on_request(id, project_id, request)
        Error(reason) -> io.println(snag.pretty_print(reason))
      }
    })

    sw.service_worker_post_message(
      worker,
      json.object([#("register", json.null())]),
    )
  })
}

pub fn spa_path(proxy) {
  let Proxy(client_id: client_id, ..) = proxy
  "/sandbox/spa/" <> client_id
}

// -----------

// run is used by the build tooling as entry point
pub fn run() -> Promise(Nil) {
  use result <- promise.map(do_run())
  case result {
    Ok(Nil) -> Nil
    Error(reason) -> io.println(snag.pretty_print(reason))
  }
}

fn do_run() {
  use self <- t.try(check_service_worker())
  let origin = sw.origin(self)
  let ref = js.make_reference(init(self, origin))
  add_fetch_listener(self, fn(event, request) {
    let #(p, state) = handle_fetch(js.dereference(ref), event, request)
    js.set_reference(ref, state)
    p
  })

  sw.self_on_message(self, fn(message) {
    let state = handle_message(js.dereference(ref), message)
    js.set_reference(ref, state)
    Nil
  })

  use Nil <- promise.await(sw.do_claim(self))
  use Nil <- promise.await(sw.skip_waiting(self))
  console.log("proxy is running for origin: " <> origin)
  t.done(Nil)
}

fn check_service_worker() {
  case sw.self() {
    Ok(self) -> Ok(self)
    Error(reason) ->
      Error(snag.new(reason) |> snag.layer("Failed service worker check"))
  }
}

type State {
  State(
    self: sw.GlobalScope,
    origin: String,
    // next cache bust
    next: Int,
    resolvers: Dict(Int, fn(Response(BitArray)) -> Nil),
    // map of client_id's to their controlling window
    captured: Dict(String, Sandbox),
  )
}

type Sandbox {
  Server(controller_id: String, project_id: String)
}

fn init(self, origin) {
  State(
    self,
    origin,
    next: int.random(1_000_000),
    resolvers: dict.new(),
    captured: dict.new(),
  )
}

pub fn send_response(proxy, caller_id, response) {
  sw.service_worker_post_message(proxy, response_payload(caller_id, response))
}

fn handle_fetch(state, event, request) {
  let State(captured: captured, origin: tours_origin, ..) = state

  let controlled =
    result.or(
      dict.get(captured, sw.resulting_client_id(event) |> io.debug),
      dict.get(captured, sw.client_id(event) |> io.debug),
    )
  let Request(scheme: scheme, host: host, port: port, ..) = request
  let origin = case scheme, host, port {
    http.Https, host, Some(443) | http.Https, host, None -> "https://" <> host
    http.Https, host, Some(p) -> "https://" <> host <> ":" <> int.to_string(p)

    http.Http, host, Some(80) | http.Http, host, None -> "http://" <> host
    http.Http, host, Some(p) -> "http://" <> host <> ":" <> int.to_string(p)
  }

  case origin == tours_origin {
    True ->
      case request.path_segments(request), controlled {
        ["sandbox", "spa", controller_id], _ -> {
          let new_id = sw.resulting_client_id(event)
          io.debug(
            "Proxying client: " <> new_id <> " to controller: " <> controller_id,
          )
          let captured =
            dict.insert(captured, new_id, Server(controller_id, "0"))
          let state = State(..state, captured: captured)
          let response =
            response.redirect("/")
            |> response.prepend_header("cache-control", "no-cache")
            |> response.set_body(conversation.Text(""))
          #(Ok(promise.resolve(response)), state)
        }
        ["sandbox", "server", controller_id, project_id], _ -> {
          let new_id = sw.resulting_client_id(event)
          io.debug(
            "Proxying client: " <> new_id <> " to controller: " <> controller_id,
          )
          let captured =
            dict.insert(captured, new_id, Server(controller_id, project_id))
          let state = State(..state, captured: captured)
          let response =
            response.redirect("/")
            |> response.prepend_header("cache-control", "no-cache")
            |> response.set_body(conversation.Text(""))
          #(Ok(promise.resolve(response)), state)
        }
        // needs to be after initial setup because refreshing page needs hard coded index
        segments, Ok(sandbox) -> {
          let file = string.join(segments, "/")
          let request = Request(..request, path: file)
          fetch_captured_request(state, sandbox, request)
        }
        ["sandbox", "gleam", _random, "0", ..], _ ->
          panic as "this usecase is not for worker or iframe"
        ["sandbox", "gleam", _run_count, controller_id, project_id, ..file], _ -> {
          let path = string.join(file, "/")
          let request = Request(..request, path: path)
          fetch_captured_request(
            state,
            Server(controller_id, project_id),
            request,
          )
        }
        _, Error(Nil) -> #(Error(Nil), state)
      }
    False -> #(Error(Nil), state)
  }
}

fn fetch_captured_request(
  state,
  sandbox,
  request: Request(conversation.RequestBody),
) {
  let State(self, origin, next_ref, resolvers, captured) = state
  let Server(controller_id, project_id) = sandbox
  io.debug(
    "Proxy received fetch request for: "
    <> request.path
    <> " from: "
    <> controller_id
    <> " project_id: "
    <> project_id,
  )

  let call_id = next_ref
  let next_ref = next_ref + 1

  // -------- HACK to get resolve function
  let ref = js.make_reference(Error(Nil))
  let p =
    promise.new(fn(resolve) {
      // previous value was error
      let assert Error(Nil) = js.set_reference(ref, Ok(resolve))
      Nil
    })
  let assert Ok(resolve) = js.dereference(ref)
  // -------- END HACK

  let resolve = fn(response: Response(BitArray)) {
    Response(
      response.status,
      response.headers,
      conversation.Bits(response.body),
    )
    |> response.prepend_header("cache-control", "no-cache")
    |> resolve
  }

  let resolvers = dict.insert(resolvers, call_id, resolve)

  promise.await(sw.client_get(self, controller_id), fn(client) {
    let assert Ok(client) = client

    use payload <- promise.await(request_payload(call_id, project_id, request))
    sw.client_post_message(client, payload)
    promise.resolve(Nil)
  })
  #(Ok(p), State(self, origin, next_ref, resolvers, captured))
}

fn handle_message(state, message) {
  case proxy_decoder(message.data(message)) {
    Ok(Register) -> {
      let client = message.source(message)
      let client_id = message.client_id(client)
      sw.client_post_message(
        client,
        json.object([#("registered", json.string(client_id))]),
      )
      state
    }
    Ok(ForwardedResponse(id, response)) -> {
      let State(resolvers: resolvers, ..) = state

      let assert Ok(resolve) = dict.get(resolvers, id)
      let resolvers = dict.delete(resolvers, id)
      case response {
        Ok(response) -> resolve(response)
        Error(reason) -> {
          io.println(reason)
          panic as " I think error case should be handled in app"
          // resolve("console.warn('" <> "No module" <> "')")
        }
      }
      State(..state, resolvers: resolvers)
    }
    Error(reason) -> {
      io.debug(reason)
      state
    }
  }
}

// ----------------------------- should be in sw library

fn add_fetch_listener(self, handler) {
  sw.add_fetch_listener(self, fn(event) {
    let request =
      sw.request(event)
      |> conversation.translate_request()
    case handler(event, request) {
      Ok(p) -> {
        let p =
          promise.map(p, fn(response) {
            response
            |> conversation.translate_response
          })
        let assert Ok(_) = sw.async_respond_with(event, p)
        Nil
      }
      Error(Nil) -> Nil
    }
  })
}
