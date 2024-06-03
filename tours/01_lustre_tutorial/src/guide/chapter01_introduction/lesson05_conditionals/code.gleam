import gleam/option.{None, Some}
import lustre
import lustre/element.{none, text}
import lustre/element/html as h

pub fn view() {
  let user = Some("Louis")

  h.div([], [
    case user {
      Some(name) -> h.span([], [text("hi "), text(name)])
      None -> text("hello stranger")
    },
  ])
}

pub fn main() {
  let app = lustre.element(view())
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
