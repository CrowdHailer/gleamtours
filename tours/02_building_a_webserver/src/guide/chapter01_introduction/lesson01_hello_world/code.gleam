import gleam/http/response

pub fn handle(_request) {
  response.new(200)
  |> response.set_body(<<"Hello World!":utf8>>)
}
