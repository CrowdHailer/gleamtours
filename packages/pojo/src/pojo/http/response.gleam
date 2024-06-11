import gleam/dynamic
import gleam/http/response.{Response}
import gleam/json
import pojo/http/utils

pub fn to_json(response) {
  let Response(status, headers, body) = response
  json.object([
    #("status", json.int(status)),
    #("headers", utils.headers_to_json(headers)),
    #("body", utils.body_to_json(body)),
  ])
}

pub fn decoder(raw) {
  dynamic.decode3(
    Response,
    dynamic.field("status", dynamic.int),
    dynamic.field("headers", utils.headers_decoder),
    dynamic.field("body", utils.body_decoder),
  )(raw)
}
