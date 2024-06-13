import gleam/http/request
import gleam/http/response
import lustre/attribute as a
import lustre/element.{text}
import lustre/element/html as h

fn render_html(resp, page) {
  resp
  |> response.set_header("content-type", "text/html")
  |> response.set_body(<<element.to_string(page):utf8>>)
}

fn home() {
  h.html([], [
    h.head([], []),
    h.body([], [
      h.h1([], [text("Hello again.")]),
      h.a([a.href("/about")], [text("About")]),
    ]),
  ])
}

fn about() {
  h.html([], [h.head([], []), h.body([], [h.h1([], [text("about")])])])
}

pub fn handle(request) {
  case request.path_segments(request) {
    [] ->
      response.new(200)
      |> render_html(home())
    ["about"] ->
      response.new(200)
      |> render_html(about())

    _ ->
      response.new(404)
      |> response.set_body(<<>>)
  }
}
