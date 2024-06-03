import gleam/string
import lustre
import lustre/element.{text}
import lustre/element/html as h

pub fn view() {
  let name = "Hayleigh"
  let name = string.reverse(name)

  h.div([], [text("Hello, "), text(name), text("!")])
}

pub fn main() {
  let app = lustre.element(view())
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
