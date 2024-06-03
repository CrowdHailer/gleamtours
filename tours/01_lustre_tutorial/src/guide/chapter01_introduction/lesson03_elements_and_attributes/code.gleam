import lustre
import lustre/attribute as a
import lustre/element.{text}
import lustre/element/html as h

const img_src = "https://gleam.run/images/lucy/lucydebugfail.svg"

// const img_src = "https://gleam.run/images/lucy/lucyjs.svg"

pub fn view() {
  h.div([], [
    h.h1([a.style([#("color", "red")])], [text("This is lucy")]),
    h.img([a.src(img_src)]),
  ])
}

pub fn main() {
  let app = lustre.element(view())
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
