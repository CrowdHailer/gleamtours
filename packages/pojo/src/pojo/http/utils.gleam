import gleam/bit_array
import gleam/dynamic
import gleam/json
import gleam/result

pub fn headers_to_json(headers) {
  // encoded as tuples
  json.array(headers, fn(h) {
    let #(k, v) = h
    json.array([k, v], json.string)
  })
}

pub fn headers_decoder(raw) {
  dynamic.list(dynamic.tuple2(dynamic.string, dynamic.string))(raw)
}

pub fn body_to_json(body) {
  json.string(bit_array.base64_encode(body, False))
}

pub fn body_decoder(raw) {
  use encoded <- result.try(dynamic.string(raw))
  bit_array.base64_decode(encoded)
  |> result.replace_error([dynamic.DecodeError("bitarray", encoded, [])])
}
