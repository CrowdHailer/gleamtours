import gleam/list
import gleam/option.{None, Some}
import gleam/uri
import lustre/attribute as a
import lustre/element
import lustre/element/html as h
import mysig/html
import mysig/preview

pub fn view(tours) {
  let content =
    html.doc(
      "Gleam tours",
      list.flatten([
        [
          html.stylesheet("/css/fonts.css"),
          html.stylesheet("/css/theme.css"),
          html.stylesheet("/common.css"),
          html.stylesheet("/css/layout.css"),
          html.stylesheet("/css/root.css"),
          html.stylesheet("/css/code/syntax-highlight.css"),
          html.stylesheet("/css/code/color-schemes/atom-one.css"),
          html.stylesheet("/css/pages/lesson.css"),
          html.plausible("gleamtours.com"),
        ],
        preview.homepage(
          title: "Gleam tours",
          description: "Interactive tours to learn about Gleam frameworks and libraries.",
          canonical: uri.Uri(
            Some("https"),
            None,
            Some("gleamtours.com"),
            None,
            "/",
            None,
            None,
          ),
        ),
        preview.optimum_image(
          uri.Uri(
            Some("https"),
            None,
            Some("gleamtours.com"),
            None,
            "/share.png",
            None,
            None,
          ),
          preview.png,
          "Lucy the Gleam mascot at a laptop computer.",
        ),
      ]),
      [
        underlay("var(--aged-plastic-yellow)", [
          h.div(
            [
              a.style([
                #("max-width", "60rem"),
                #("width", "100%"),
                #("margin", "0 auto"),
                #("padding", "1rem"),
              ]),
            ],
            [
              hstack([#("gap", "1rem"), #("font-size", "1.2rem")], [
                logo("30px"),
                h.span([a.style([#("flex-grow", "1")])], [
                  element.text("Gleam tours"),
                ]),
                h.span([], [
                  h.a([a.href("https://github.com/CrowdHailer/gleamtours")], [
                    element.text("code"),
                  ]),
                ]),
              ]),
            ],
          ),
          h.div(
            [
              a.style([
                #("max-width", "60rem"),
                #("margin", "40px auto 80px"),
                #("flex-grow", "1"),
              ]),
            ],
            [
              hstack([#("gap", "2rem")], [
                logo("300px"),
                h.div([a.style([])], [
                  h.p([a.style([#("font-size", "2rem"), #("margin", "1rem")])], [
                    element.text("Learn about Gleam frameworks and libraries."),
                  ]),
                  h.p(
                    [a.style([#("font-size", "1.2rem"), #("margin", "1rem")])],
                    [
                      element.text(
                        "All tours are interactive and run right here in your browser, no install or setup needed.",
                      ),
                    ],
                  ),
                ]),
              ]),
              h.div(
                [],
                list.map(tours, fn(t) {
                  let #(title, description, first) = t
                  h.a(
                    [
                      a.style([
                        #("display", "block"),
                        #("text-decoration", "none"),
                        #("margin", "20px 0"),
                        #("border", "1px solid"),
                        #("padding", "0 9px"),
                        #("border-left", "10px solid"),
                        #("border-radius", "20px"),
                        #("border-color", "var(--underwater-blue)"),
                      ]),
                      a.href(first),
                    ],
                    [
                      h.h3([], [element.text(title)]),
                      h.p([], [element.text(description)]),
                    ],
                  )
                }),
              ),
              h.div([a.style([#("font-style", "italic")])], [
                element.text(
                  "More tours coming soon. They will be announced in the ",
                ),
                h.a([a.href("https://gleamweekly.com/")], [
                  element.text("Gleam Weekly"),
                ]),
                element.text(" newsletter when they are available."),
              ]),
            ],
          ),
          h.img([
            a.style([#("width", "100%"), #("margin", "-10px 0")]),
            a.src("https://gleam.run/images/waves.svg"),
          ]),
          h.div(
            [
              a.style([
                #("background", "var(--underwater-blue)"),
                #("color", "white"),
              ]),
            ],
            [
              h.div(
                [
                  a.style([
                    #("max-width", "60rem"),
                    #("margin", "0 auto"),
                    #("padding", "1rem"),
                  ]),
                ],
                [
                  hstack(
                    [
                      #("gap", "1rem"),
                      #("width", "100%"),
                      #("font-size", "1.2rem"),
                    ],
                    [
                      logo("30px"),
                      h.span([a.style([#("flex-grow", "1")])], [
                        element.text("Gleam tours"),
                      ]),
                      h.span([], [
                        h.a(
                          [a.href("https://github.com/CrowdHailer/gleamtours")],
                          [element.text("code")],
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ]),
      ],
    )
    |> element.to_document_string()
  <<content:utf8>>
}

fn underlay(color, children) {
  h.div(
    [
      a.style([
        #("min-height", "100vh"),
        #("background", color),
        #("display", "flex"),
        #("flex-direction", "column"),
      ]),
    ],
    children,
  )
}

fn hstack(extra, children) {
  h.div(
    [
      a.style([
        #("display", "flex"),
        #("width", "100%"),
        #("align-items", "center"),
        #("justify-content", "center"),
        ..extra
      ]),
    ],
    children,
  )
}

fn logo(size) {
  h.img([
    a.src("https://gleam.run/images/lucy/lucy.svg"),
    a.alt("Lucy the star, Gleam's mascot"),
    a.style([#("max-width", size)]),
  ])
}
