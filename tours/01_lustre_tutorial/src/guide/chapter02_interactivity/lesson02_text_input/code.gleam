import lustre
import lustre/attribute as a
import lustre/element.{text}
import lustre/element/html as h
import lustre/event

fn init(_) {
  "world"
}

pub type Message {
  UpdateName(String)
  ResetName
}

pub fn update(_model, message) {
  case message {
    UpdateName(new) -> new
    ResetName -> "world"
  }
}

pub fn view(model) {
  h.div([], [
    h.div([], [h.input([a.value(model), event.on_input(UpdateName)])]),
    h.div([], [h.button([event.on_click(ResetName)], [text("Reset")])]),
    h.div([], [text("hello "), text(model)]),
  ])
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
