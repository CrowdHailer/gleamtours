import gleam/list
import gleam/option.{None, Some}
import gleam/uri
import gleamtours/components
import lustre/attribute as a
import lustre/element
import lustre/element/html as h
import mysig/html
import mysig/preview

fn html_script(src) {
  h.script([a.src(src)], "")
}

pub fn render(
  tour tour,
  description description,
  contents_path contents_path,
  chapter _chapter,
  lesson lesson,
  text text,
  code code,
  self self,
  previous previous,
  next next,
) {
  let content =
    html.doc(
      tour,
      list.flatten([
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
          html_script(
            "https://unpkg.com/@rollup/browser/dist/rollup.browser.js",
          ),
        ],
        preview.page(
          site: "Gleam tours",
          title: tour,
          description: description,
          canonical: uri.Uri(
            Some("https"),
            None,
            Some("gleamtours.com"),
            None,
            self,
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
