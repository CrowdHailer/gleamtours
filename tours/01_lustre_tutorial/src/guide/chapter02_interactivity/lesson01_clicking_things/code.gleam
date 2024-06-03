import gleam/int
import lustre
import lustre/element.{text}
import lustre/element/html as h
import lustre/event

fn init(_) {
  0
}

pub type Message {
  Increment
  Decrement
}

pub fn update(model, message) {
  case message {
    Increment -> model + 1
    Decrement -> model - 1
  }
}

pub fn view(model) {
  let count = int.to_string(model)

  h.div([], [
    h.button([event.on_click(Increment)], [text("+")]),
    text(count),
    h.button([event.on_click(Decrement)], [text("-")]),
  ])
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
