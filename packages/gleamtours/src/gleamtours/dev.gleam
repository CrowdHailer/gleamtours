import filepath
import gleam/bit_array
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import gleamtours/index
import gleamtours/lesson
import glen_node
import midas/js/run as r
import midas/sdk/netlify
import midas/shell
import midas/shell/file_system as fs
import midas/shell/gleam
import midas/shell/rollup
import midas/task as t
import netlify as netlify_local
import simplifile
import snag
import tour

const site_id = "3847b531-b17d-438b-b780-e20d91675542"

// This sould be reusable somewhere else
fn bundle_js(dir, module, func) {
  use js_dir <- r.try(gleam.build_js(dir))

  let assert Ok(#(package, _)) = string.split_once(module, "/")
  // Assumes that the package and module share name at top level
  let module_path = string.concat([package, "/", module])

  rollup.bundle_fn(js_dir, module_path, func)
}

fn build(netlify_app) {
  use project <- r.try(fs.current_directory())

  let tour_styles = [
    "/common.css", "/css/fonts.css", "/css/theme.css", "/css/layout.css",
    "/css/root.css", "/css/pages/everything.css", "/css/pages/lesson.css",
    "/css/code/syntax-highlight.css", "/css/code/color-schemes/atom-one.css",
  ]

  let tour_static_dir =
    string.replace(project, "/mono-2024/ctrl", "/language-tour/static")
  // needs to be a t.try_promise_map for proper use of t inside
  use static <- r.try(
    list.try_map(tour_styles, fn(path) {
      let full_path = string.append(tour_static_dir, path)
      case fs.read(full_path) {
        Ok(bits) -> Ok(#(path, bits))
        Error(reason) -> Error(reason)
      }
    }),
  )

  // index.js name is used by the lesson template
  let module = "gleamtours/lesson"
  let func = "app"
  use index_js <- r.await(bundle_js(project, module, func))
  let index_js = bit_array.from_string(index_js)

  use compiler_assets <- r.try(fs.read_directory_content(
    "priv/vendor/wasm-compiler",
  ))

  let compiler_assets =
    list.map(compiler_assets, fn(file) {
      let #(name, bits) = file
      #(filepath.join("/wasm-compiler", name), bits)
    })

  let module = "gleamtours/sandbox/proxy"
  let func = "run"
  use proxy_js <- r.await(bundle_js(project, module, func))
  let proxy_js = bit_array.from_string(proxy_js)

  let tours_dir =
    string.replace(project, "/mono-2024/ctrl", "/gleamtours/tours")
  use filenames <- r.try(tour.load_directory_names(tours_dir))

  use tours <- r.try(
    list.try_map(filenames, fn(filenames) {
      let tour.FileNames(path, name, slug) = filenames
      let src_path = filepath.join(path, "src/guide")
      use chapters <- result.try(tour.do_load_content(src_path, None, None))

      let prepend = fn(path) { string.concat(["/", slug, path]) }
      let chapters =
        list.map(chapters, fn(c) {
          let lessons =
            list.map(c.lessons, fn(l) {
              tour.Lesson(
                ..l,
                path: prepend(l.path),
                previous: option.map(l.previous, prepend),
                next: option.map(l.next, prepend),
                next: option.map(l.next, prepend),
              )
            })
          tour.Chapter(..c, lessons: lessons)
        })

      let contents =
        tour.Lesson(
          name: "Table of Contents",
          text: tour.contents_list_html(chapters),
          code: "",
          path: "/" <> slug,
          previous: None,
          next: None,
        )
      let assert [first, ..lessons] =
        list.flat_map(chapters, fn(c) { c.lessons })
      let lessons = [contents, first, ..lessons]

      let packages_dir = filepath.join(path, "build/packages")
      use packages <- result.try(
        fs.read_directory(packages_dir)
        |> snag.context("Could not read packages for " <> name),
      )

      let packages =
        list.filter_map(packages, fn(p) {
          let src = filepath.join(packages_dir, p)
          let src = filepath.join(src, "src")
          case simplifile.get_files(src) {
            Ok(files) -> {
              list.map(files, fn(file) {
                let assert Ok(#("", relative)) = string.split_once(file, src)
                let assert Ok(module) = simplifile.read(file)
                #(relative, module)
              })
              |> Ok
            }
            Error(_) -> Error(Nil)
          }
        })
      let files = list.flatten(packages)

      let src_dir = filepath.join(path, "src")
      use src <- result.try(
        fs.get_files(src_dir)
        |> snag.context("Could not read src for " <> name),
      )
      let guide_dir = filepath.join(src_dir, "guide")
      let src =
        list.filter(src, fn(path) { !string.starts_with(path, guide_dir) })

      let src_files =
        list.map(src, fn(src) {
          let assert Ok(#("", "/" <> relative)) =
            string.split_once(src, src_dir)
          let assert Ok(module) = simplifile.read(src)
          #(relative, module)
        })
      let files = list.append(files, src_files)

      let deps_js = bit_array.from_string(generate_deps_bundle(files))

      Ok(#(name, slug, first.path, lessons, deps_js))
    }),
  )
  let pages =
    list.flat_map(tours, fn(tour) {
      let #(tour_name, slug, _first_path, lessons, deps_js) = tour
      list.map(lessons, fn(lesson) {
        let content =
          lesson.page(lesson)
          |> string.replace("Gleam Language Tour", tour_name)
          |> string.replace(
            "</head>",
            "<script src=\"https://unpkg.com/@rollup/browser/dist/rollup.browser.js\"></script><script defer data-domain=\"gleamtours.com\" src=\"https://plausible.io/js/script.js\"></script></head>",
          )
          |> string.replace("table-of-contents", slug)
          |> bit_array.from_string()
        #(string.append(lesson.path, "/index.html"), content)
      })
      |> list.append([#("/" <> slug <> "/deps.js", deps_js)])
    })

  let index = bit_array.from_string(index.view(tours))

  let auth_page =
    bit_array.from_string(
      "
<script>
  const channel = new BroadcastChannel('auth')
  channel.postMessage({service: 'twitter', redirect: window.location.href})
</script>
",
    )
  let netlify_auth_page =
    bit_array.from_string(
      "
<script>
  const channel = new BroadcastChannel('auth')
  channel.postMessage({service: 'netlify', redirect: window.location.href})
</script>
",
    )
  let pages =
    list.concat([
      [
        #("/_redirects", bit_array.from_string(redirects)),
        #("/auth/twitter/index.html", auth_page),
        #("/auth/netlify/index.html", netlify_auth_page),
        #("/index.html", index),
        #("/proxy.js", proxy_js),
        #("/index.js", index_js),
        ..static
      ],
      pages,
      compiler_assets,
    ])
  r.done(pages)
}

fn generate_deps_bundle(files) {
  let entries =
    list.map(files, fn(file) {
      let #(path, code) = file
      let code =
        code
        |> string.replace("\\", "\\\\")
        |> string.replace("`", "\\`")
        |> string.replace("$", "\\$")

      // uses backticks doesn't escape quotes
      "  \"" <> path <> "\": `" <> code <> "`"
    })

  entries
  |> string.join(",\n")
  |> string.append("export default {\n", _)
  |> string.append("\n}\n")
}

// public preview and deploy fn
const redirects = "/proxy/* https://:splat 200
"

pub fn preview(local_app) {
  let work = r.map_error(build(local_app), snag.layer(_, "Build failed"))
  use files <- r.await(work)
  io.debug("serving")
  let Nil = glen_node.serve(8080, netlify_local.dev(files))
  r.done(Nil)
}

fn do_deploy(app, site_id, content) {
  use token <- t.do(netlify.authenticate(app))
  netlify.deploy_site(token, site_id, content)
}

pub const ctrl_prod_app = netlify.App(
  "-YQebIC-PkC4ANX-5OC_qdO3cW9x8RAVoEzzqL6Ssu8",
  "https://gleamtours.com/auth/netlify",
)

pub fn deploy(app, root) {
  let work = r.map_error(build(ctrl_prod_app), snag.layer(_, "Build failed"))
  use content <- r.await(work)
  use response <- r.await(shell.run(do_deploy(app, site_id, content), root))
  io.debug(response)
  r.done(Nil)
}
// pub fn run(args) {
//   case args {
//     // ["fetch-wasm"] -> {
//     //   use Nil <- t.try(fs.create_directory_all("priv/vendor/wasm-compiler"))
//     //   shellout.command(
//     //     run: "curl",
//     //     with: [
//     //       " -L \"https://github.com/gleam-lang/gleam/releases/download/1.1.0/gleam-1.1.0-browser.tar.gz\" | tar xz",
//     //     ],
//     //     in: "priv/vendor/wasm-compiler",
//     //     opt: [],
//     //   )
//     //   |> io.debug
//     //   t.done(Nil)
//     // }
//     // ["deploy"] -> {
//     // }
//     _ -> t.fail(snag.new("no task for gleamtours"))
//   }
// }
