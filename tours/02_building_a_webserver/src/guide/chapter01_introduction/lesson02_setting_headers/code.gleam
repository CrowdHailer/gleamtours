import gleam/http/response
import lustre/element.{text}
import lustre/element/html as h

fn content() {
  h.div([], [
    h.h1([], [text("Hello, World!")]),
    h.p([], [text("This is our first HTML page")]),
  ])
}

fn page() {
  <<element.to_string(content()):utf8>>
}

pub fn handle(_request) {
  response.new(200)
  |> response.set_header("content-type", "text/html")
  |> response.set_body(page())
}
