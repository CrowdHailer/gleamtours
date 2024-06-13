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

fn render_css(resp, css) {
  resp
  |> response.set_header("content-type", "text/css")
  |> response.set_body(<<css:utf8>>)
}

fn home() {
  h.html([], [
    h.head([], [h.link([a.rel("stylesheet"), a.href("/style.css")])]),
    h.body([], [h.h1([], [text("Hello again.")])]),
  ])
}

pub fn handle(request) {
  case request.path_segments(request) {
    [] ->
      response.new(200)
      |> render_html(home())
    ["style.css"] ->
      response.new(200)
      |> render_css("h1 { color:blue; }")

    _ ->
      response.new(404)
      |> response.set_body(<<>>)
  }
}
