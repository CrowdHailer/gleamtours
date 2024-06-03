import gleam/list
import lustre
import lustre/element.{text}
import lustre/element/html as h

pub fn view() {
  let fruits = ["apple", "orange", "banana"]

  h.ol(
    [],
    list.map(fruits, fn(fruit) { h.li([], [text("tasty "), text(fruit)]) }),
  )
}

pub fn main() {
  let app = lustre.element(view())
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
