import gleam/http/response

pub fn handle(request) {
  response.new(500)
  |> response.set_body(<<>>)
}
