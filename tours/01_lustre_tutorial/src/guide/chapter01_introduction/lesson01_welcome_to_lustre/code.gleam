import lustre
import lustre/element.{text}
import lustre/element/html as h

pub fn view() {
  h.div([], [text("Hello, world")])
}

pub fn main() {
  let app = lustre.element(view())
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
