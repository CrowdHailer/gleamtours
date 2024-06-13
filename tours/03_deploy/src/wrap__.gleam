import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/io
import gleam/json
import gleam/uri
import main
import midas/task as t
import pojo/http/request
import pojo/http/response
import pojo/http/utils
import pojo/result
import snag

// needed because recursive type
pub type Serialized {
  Serialized(String, json.Json, fn(Dynamic) -> Serialized)
}

pub fn serialize(eff) {
  case eff {
    t.Bundle(module, function, then) ->
      Serialized(
        "Bundle",
        json.object([
          #("module", json.string(module)),
          #("function", json.string(function)),
        ]),
        fn(value) {
          let assert Ok(result) =
            result.decoder(dynamic.string, dynamic.string)(value)
          serialize(then(result))
        },
      )

    t.Follow(url, then) ->
      Serialized("Follow", json.string(url), fn(value) {
        let assert Ok(url) = dynamic.string(value)
        serialize(then(uri.parse(url)))
      })
    t.Fetch(request, then) ->
      Serialized("Fetch", request.to_json(request), fn(value) {
        let assert Ok(response) =
          result.decoder(response.decoder, fn(raw) {
            case dynamic.string(raw) {
              Ok(s) -> Ok(t.NetworkError(s))
              Error(reason) -> Error(reason)
            }
          })(value)
        serialize(then(response))
      })
    t.Log(message, then) ->
      Serialized("Log", json.string(message), fn(_value) {
        serialize(then(Ok(Nil)))
      })
    t.Zip(files, then) ->
      Serialized(
        "Zip",
        json.array(files, fn(f) {
          let #(name, content) = f
          json.object([
            #("name", json.string(name)),
            #("content", json.string(bit_array.base64_encode(content, False))),
          ])
        }),
        fn(value) {
          let assert Ok(zipped) = utils.body_decoder(value)
          serialize(then(Ok(zipped)))
        },
      )
    t.Done(value) ->
      Serialized("Done", dynamic.unsafe_coerce(dynamic.from(value)), fn(_) {
        panic as "should not have continued"
      })
    t.Abort(reason) ->
      Serialized("Abort", json.string(snag.pretty_print(reason)), fn(_) {
        panic as "should not have continued"
      })
  }
}

pub fn run() {
  serialize(main.run())
}
