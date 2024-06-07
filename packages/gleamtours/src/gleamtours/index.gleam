import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import lustre/element/html as h

pub const tailwind = "https://unpkg.com/tailwindcss@2.2.11/dist/tailwind.min.css"

fn viewport(domain) {
  [
    h.meta([a.attribute("charset", "UTF-8")]),
    h.meta([
      a.attribute("http-equiv", "X-UA-Compatible"),
      a.attribute("content", "IE=edge"),
    ]),
    h.meta([a.attribute("viewport", "width=device-width, initial-scale=1.0")]),
    h.script(
      [
        a.attribute("defer", ""),
        a.attribute("data-domain", domain),
        a.src("https://plausible.io/js/script.js"),
      ],
      "",
    ),
  ]
}

fn standard(head, body) {
  h.html([a.attribute("lang", "en")], [
    h.head([], list.append(viewport("gleamtours.com"), head)),
    h.body([], body),
  ])
}

fn page(content) {
  standard(
    [
      h.link([a.rel("stylesheet"), a.href(tailwind)]),
      h.link([
        a.rel("stylesheet"),
        a.href(" https://tour.gleam.run/css/code/syntax-highlight.css"),
      ]),
      // not part of this project
      h.link([a.rel("stylesheet"), a.href("/layout.css")]),
    ],
    [h.div([a.class("vstack mx-auto max-w-2xl")], content)],
  )
  |> element.to_document_string
}

pub fn view(tours) {
  page([
    h.ol(
      [],
      list.map(tours, fn(tour) {
        let #(name, _slug, first_path, _lessons, _deps) = tour

        h.li([], [h.a([a.href(first_path)], [text(name)])])
      }),
    ),
  ])
}
