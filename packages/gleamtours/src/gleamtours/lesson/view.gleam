import gleam/option.{None, Some}
import gleamtours/components
import lustre/attribute as a
import lustre/element
import lustre/element/html as h
import mysig/html

fn html_script(src) {
  h.script([a.src(src)], "")
}

pub fn render(
  tour tour,
  contents_path contents_path,
  chapter _chapter,
  lesson lesson,
  text text,
  code code,
  previous previous,
  next next,
) {
  let content =
    html.doc(
      tour,
      [
        html.stylesheet("/css/fonts.css"),
        html.stylesheet("/css/theme.css"),
        html.stylesheet("/common.css"),
        html.stylesheet("/css/layout.css"),
        html.stylesheet("/css/root.css"),
        // html.stylesheet("/css/pages/everything.css"),
        html.stylesheet("/css/code/syntax-highlight.css"),
        html.stylesheet("/css/code/color-schemes/atom-one.css"),
        html.stylesheet("/css/pages/lesson.css"),
        html.plausible("gleamtours.com"),
        html_script("https://unpkg.com/@rollup/browser/dist/rollup.browser.js"),
      ],
      [
        components.navbar(tour),
        h.article([a.id("playground")], [
          h.section([a.id("left"), a.class("content-nav")], [
            h.div([], [
              h.h2([], [element.text(lesson)]),
              h.div([a.attribute("dangerous-unescaped-html", text)], []),
            ]),
            h.nav([a.class("prev-next")], [
              navlink("Back", previous),
              element.text(" — "),
              h.a([a.href(contents_path)], [element.text("Contents")]),
              element.text(" — "),
              navlink("Next", next),
            ]),
          ]),
          h.div([a.id("app"), a.style([#("flex-grow", "1")])], []),
        ]),
        h.script([a.id("code"), a.type_("gleam")], code),
        h.script([a.src("/index.js"), a.type_("module")], ""),
      ],
    )
    |> element.to_document_string()
  <<content:utf8>>
}

fn navlink(name, link) {
  case link {
    None -> h.span([], [element.text(name)])
    Some(path) -> h.a([a.href(path)], [element.text(name)])
  }
}
