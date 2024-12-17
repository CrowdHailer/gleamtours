import lustre/attribute as a
import lustre/element
import lustre/element/html as h

pub fn navbar(titled title: String) {
  let nav_right_items = [
    // theme_picker()
  ]

  h.nav([a.class("navbar")], [
    h.a([a.href("/"), a.class("logo")], [
      h.img([
        a.src("https://gleam.run/images/lucy/lucy.svg"),
        a.alt("Lucy the star, Gleam's mascot"),
      ]),
      element.text(title),
    ]),
    h.div([a.class("nav-right")], nav_right_items),
  ])
}
