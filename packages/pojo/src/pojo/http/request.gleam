import gleam/dynamic
import gleam/http
import gleam/http/request.{Request}
import gleam/json
import gleam/result
import pojo/http/utils

pub fn to_json(request) {
  let Request(method, headers, body, scheme, host, port, path, query) = request
  json.object([
    #("method", json.string(http.method_to_string(method))),
    #("headers", utils.headers_to_json(headers)),
    #("body", utils.body_to_json(body)),
    #("scheme", json.string(http.scheme_to_string(scheme))),
    #("host", json.string(host)),
    #("port", json.nullable(port, json.int)),
    #("path", json.string(path)),
    #("query", json.nullable(query, json.string)),
  ])
}

pub fn decoder(raw) {
  dynamic.decode8(
    Request,
    dynamic.field("method", http.method_from_dynamic),
    dynamic.field("headers", utils.headers_decoder),
    dynamic.field("body", utils.body_decoder),
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
