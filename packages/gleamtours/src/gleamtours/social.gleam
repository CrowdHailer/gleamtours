import gleam/option.{Some}
import lustre/attribute as a
import lustre/element
import lustre/element/html as h
import midas/task as t

const aged_plastic_yellow = "#fffbe8"

const unexpected_aubergine = "#584355"

const underwater_blue = "#292d3e"

const charcoal = "#2f2f2f"

const black = "#1e1e1e"

const blacker = "#151515"

fn render() {
  h.body(
    [
      a.style([
        #("margin", "0"),
        #("width", "1200px"),
        #("max-height", "630px"),
        #("height", "100vh"),
        #("display", "flex"),
        #("flex-direction", "column"),
        #("background-color", aged_plastic_yellow),
        #("font-family", "\"Outfit\", sans-serif"),
      ]),
    ],
    [
      h.div(
        [
          a.style([
            #("padding", "0 20px"),
            #("flex-grow", "1"),
            #("display", "flex"),
            #("align-items", "center"),
            #("justify-content", "center"),
          ]),
        ],
        [
          h.img([
            a.src("https://gleam.run/images/lucy/lucydebugfail.svg"),
            a.alt("Lucy the star, Gleam's mascot"),
            a.style([#("max-width", "460px")]),
          ]),
          h.div([], [
            h.div([a.style([#("color", blacker), #("font-size", "5rem")])], [
              element.text("Interactive tours"),
              h.div([a.style([#("color", blacker), #("font-size", "3rem")])], [
                element.text("in Gleam"),
              ]),
            ]),
          ]),
        ],
      ),
      h.img([
        a.style([#("width", "100%"), #("margin-bottom", "-1px")]),
        a.src("https://gleam.run/images/waves.svg"),
      ]),
      h.div(
        [a.style([#("height", "60px"), #("background", underwater_blue)])],
        [],
      ),
    ],
  )
  |> element.to_document_string
}

// run can open and screenshot 
// serve and receive

pub fn serve() {
  // serve_static needs to do mimes properly currently only no extension gets html
  t.serve_static(Some(8080), [#("/", <<render():utf8>>)])
}
