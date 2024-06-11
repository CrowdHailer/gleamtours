import gleam/dynamic
import gleam/json

pub fn to_json(ok_encoder, error_encoder) {
  fn(value) {
    case value {
      Ok(value) -> json.object([#("Ok", ok_encoder(value))])
      Error(reason) -> json.object([#("Error", error_encoder(reason))])
    }
  }
}

pub fn decoder(ok_decoder, error_decoder) {
  dynamic.any([
    dynamic.decode1(Ok, dynamic.field("Ok", ok_decoder)),
    dynamic.decode1(Error, dynamic.field("Error", error_decoder)),
  ])
}
