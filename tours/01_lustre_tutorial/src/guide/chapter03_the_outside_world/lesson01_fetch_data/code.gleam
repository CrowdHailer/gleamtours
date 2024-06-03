import cat_fact
import gleam/javascript/promise
import gleam/option.{type Option, None, Some}
import lustre
import lustre/effect
import lustre/element.{text}
import lustre/element/html as h
import lustre/event

type Model {
  NotLoaded(error: Option(String))
  Loading
  Loaded(fact: String)
}

fn init(_) {
  #(NotLoaded(None), effect.none())
}

type Message {
  FetchCatFact
  CatFactFetched(fact: String)
  FetchFailed(reason: String)
}

fn fetch_fact(dispatch) {
  promise.map(cat_fact.fetch(), fn(response) {
    let message = case response {
      Ok(fact) -> CatFactFetched(fact)
      Error(reason) -> FetchFailed(reason)
    }
    dispatch(message)
  })
  Nil
}

fn update(_model, message) {
  case message {
    FetchCatFact -> #(Loading, effect.from(fetch_fact))
    CatFactFetched(fact) -> #(Loaded(fact), effect.none())
    FetchFailed(reason) -> #(NotLoaded(Some(reason)), effect.none())
  }
}

fn view(model) {
  h.div([], [
    h.div([], [h.h1([], [text("Cat facts")])]),
    case model {
      NotLoaded(_) ->
        h.button([event.on_click(FetchCatFact)], [text("fetch fact")])
      Loading -> text("loading")
      Loaded(fact) ->
        h.div([], [
          h.span([], [text("did you know. "), text(fact)]),
          h.div([], [
            h.button([event.on_click(FetchCatFact)], [text("fetch new fact")]),
          ]),
        ])
    },
  ])
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "div", Nil)
  Nil
}
