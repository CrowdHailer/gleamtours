// import gleam/dynamic
// import gleam/fetch
// import gleam/http/request
import gleam/javascript/promise

// import gleam/string
// import gleam/uri

// fn decoder() {
//   dynamic.field("fact", dynamic.string)
// }

// pub fn fetch() {
//   let assert Ok(url) = uri.parse("https://catfact.ninja/fact")
//   let assert Ok(request) = request.from_uri(url)

//   use response <- promise.await(fetch.send(request))
//   case response {
//     Ok(response) -> {
//       use response <- promise.map(fetch.read_json_body(response))
//       case response {
//         Ok(response) ->
//           case decoder()(response.body) {
//             Ok(data) -> Ok(data)
//             Error(reason) -> Error(string.inspect(reason))
//           }
//         Error(reason) -> Error(string.inspect(reason))
//       }
//     }
//     Error(reason) -> promise.resolve(Error(string.inspect(reason)))
//   }
// }

@external(javascript, "./cat_fact_ffi.mjs", "fetchFact")
pub fn fetch() -> promise.Promise(Result(String, String))
