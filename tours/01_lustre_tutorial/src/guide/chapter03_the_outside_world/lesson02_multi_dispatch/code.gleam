import gleam/int
import lustre
import lustre/effect
import lustre/element.{text}
import lustre/element/html as h
import timer

fn load_items(dispatch) {
  use <- timer.set_timeout(1000)
  dispatch(Progressed(20))

  use <- timer.set_timeout(2000)
  dispatch(Progressed(50))

  use <- timer.set_timeout(2000)
  dispatch(Progressed(30))
}

fn init(_) {
  #(0, effect.from(load_items))
}

type Message {
  Progressed(amount: Int)
}

fn update(model, message) {
  case message {
    Progressed(amount) -> #(model + amount, effect.none())
  }
}

fn view(model) {
  h.div([], [text("loaded "), text(int.to_string(model)), text(" items.")])
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
