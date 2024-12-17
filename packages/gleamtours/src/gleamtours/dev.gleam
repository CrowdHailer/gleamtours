import gleam/bit_array
import gleam/io
import gleam/javascript/array
import gleam/javascript/promise
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleamtours/index
import gleamtours/lesson/view
import justin
import lustre/attribute as a
import lustre/element
import lustre/element/html as h
import midas/node
import midas/sdk/netlify
import midas/task as t
import mysig/local
import plinth/node/process
import snag

const site_id = "3847b531-b17d-438b-b780-e20d91675542"

pub fn main() {
  do_main(list.drop(array.to_list(process.argv()), 2))
}

pub fn do_main(args) {
  case args {
    [] ->
      promise.map(
        // At level where language tour is relative
        node.watch(develop(args), "../../..", fn(result) {
          case result {
            Ok(Nil) -> Nil
            Error(reason) -> io.println(snag.pretty_print(reason))
          }
        }),
        fn(_) { 0 },
      )
    ["build"] -> {
      use result <- promise.map(node.run(build(), "../../.."))
      case result {
        Ok(_) -> "GOOD"
        Error(reason) -> snag.pretty_print(reason)
      }
      |> io.print
      0
    }
    ["deploy"] -> {
      use result <- promise.map(node.run(deploy(), "../../.."))
      case result {
        Ok(_) -> "GOOD"
        Error(reason) -> snag.pretty_print(reason)
      }
      |> io.print
      0
    }
    _ -> panic as "not supported"
  }
}

fn develop(_args) {
  use files <- t.do(build())
  local.serve(Some(8080), files)
}

fn deploy() {
  let local =
    netlify.App(
      "cQmYKaFm-2VasrJeeyobXXz5G58Fxy2zQ6DRMPANWow",
      "http://localhost:8080/auth/netlify",
    )

  use token <- t.do(netlify.authenticate(local))
  use content <- t.do(build())
  netlify.deploy_site(token, site_id, content)
}

// from disk module
fn load_prefix(root, prefix) {
  use items <- t.do(t.list(root))
  list.filter_map(items, fn(item) {
    case string.split_once(item, prefix) {
      Ok(#("", rest)) ->
        case string.split_once(rest, "_") {
          Ok(#(_number, rest)) -> {
            // io.debug(int.parse(number))
            Ok(#(
              root <> "/" <> item,
              justin.sentence_case(rest),
              justin.kebab_case(rest),
            ))
          }
          Error(Nil) -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
  |> t.done()
}

type LessonData {
  LessonData(
    path: String,
    name: String,
    chapter_name: String,
    text: String,
    code: String,
  )
}

fn render_lesson(lesson, prev, next, tour) {
  let #(_, tour, slug) = tour
  let LessonData(_path, name, chapter_name, text, code) = lesson
  view.render(
    tour: tour,
    contents_path: "/" <> slug,
    chapter: chapter_name,
    lesson: name,
    text: text,
    code: code,
    previous: option.map(prev, fn(d: LessonData) { d.path }),
    next: option.map(next, fn(d: LessonData) { d.path }),
  )
}

fn render_lessons(lessons, prev, tour, acc) {
  case lessons {
    [] -> list.reverse(acc)
    [lesson, ..rest] -> {
      let next = list.first(rest) |> option.from_result
      let content = render_lesson(lesson, prev, next, tour)
      let acc = [#(lesson.path, content), ..acc]
      render_lessons(rest, Some(lesson), tour, acc)
    }
  }
}

fn read_files(root) {
  case string.contains(root, ".") {
    True -> t.done([root])
    False -> {
      use children <- t.do(t.list(root))
      use nested <- t.do(
        t.sequential(
          list.map(children, fn(child) { read_files(root <> "/" <> child) }),
        ),
      )
      t.done(list.flatten(nested))
    }
  }
}

// read all the source files that are in the packages directory so they can be passed to the compiler
fn read_package_src(path) {
  let packages_dir = path <> "/build/packages"
  use packages <- t.do(t.list(packages_dir))
  use files <- t.do(
    t.sequential(
      list.map(packages, fn(package) {
        case string.contains(package, ".") {
          True -> t.done([])
          False -> {
            let src_dir = packages_dir <> "/" <> package <> "/src"
            use files <- t.do(read_files(src_dir))
            list.map(files, fn(file) {
              let assert Ok(#("", relative)) = string.split_once(file, src_dir)
              use module <- t.do(t.read(file))
              let assert Ok(module) = bit_array.to_string(module)
              t.done(#(relative, module))
            })
            |> t.sequential()
          }
        }
      }),
    ),
  )
  t.done(list.flatten(files))
}

// catalogue of tours tour is equivalent to guide or course
// compiler assets can be downloaded and then unzipped
fn build() {
  use static <- t.do(load_tour_styles())
  use index_js <- t.do(t.bundle("gleamtours/lesson", "app"))

  use compiler_assets <- t.do(read_compiler_assets())
  use proxy_js <- t.do(t.bundle("gleamtours/sandbox/proxy", "run"))

  let path = "/gleamtours/tours"
  use tours <- t.do(load_prefix(path, ""))
  use lessons <- t.do(
    t.sequential(
      list.map(tours, fn(tour) {
        let #(path, _tour_name, tour_slug) = tour

        let src_path = path <> "/src/guide"
        use chapters <- t.do(load_prefix(src_path, "chapter"))
        use lessons <- t.do(
          t.sequential(
            list.map(chapters, fn(c) {
              let #(path, chapter_name, chapter_slug) = c
              use lessons <- t.do(load_prefix(path, "lesson"))
              t.sequential(
                list.map(lessons, fn(l) {
                  let #(path, name, slug) = l

                  use text <- t.do(t.read(path <> "/en.html"))
                  let assert Ok(text) = bit_array.to_string(text)
                  use code <- t.do(t.read(path <> "/code.gleam"))
                  let assert Ok(code) = bit_array.to_string(code)

                  let path =
                    "/"
                    <> tour_slug
                    <> "/"
                    <> chapter_slug
                    <> "/"
                    <> slug
                    <> "/index.html"
                  t.done(LessonData(path, name, chapter_name, text, code))
                }),
              )
            }),
          ),
        )
        let assert Ok(chapters) = list.strict_zip(chapters, lessons)
        let content =
          chapters
          |> list.flat_map(fn(chapter) {
            let #(#(_, name, _), lessons) = chapter
            [
              h.h3([a.class("mb-0")], [element.text(name)]),
              h.ul(
                [],
                list.map(lessons, fn(lesson: LessonData) {
                  h.li([], [
                    h.a([a.href(lesson.path)], [element.text(lesson.name)]),
                  ])
                }),
              ),
            ]
          })
        let lessons = list.flatten(lessons)
        let lesson_pages = render_lessons(lessons, None, tour, [])

        let contents_path = "/" <> tour_slug <> "/index.html"
        let contents_page =
          render_lesson(
            LessonData(
              path: contents_path,
              name: "Table of Contents",
              chapter_name: "",
              text: element.to_string(element.fragment(content)),
              code: "",
            ),
            None,
            None,
            tour,
          )
        use deps <- t.do(read_package_src(path))

        let deps = #("/" <> tour_slug <> "/deps.js", <<
          generate_deps_bundle(deps):utf8,
        >>)
        [#(contents_path, contents_page), deps, ..lesson_pages]
        |> t.done()
      }),
    ),
  )
  let lessons = list.flatten(lessons)
  let tours = [
    #(
      "Lustre tutorial",
      "Get started building your first web app with the Lusture tutorial.",
      "/lustre-tutorial/introduction/welcome-to-lustre",
    ),
    // #(
  //   "Building a webserver",
  //   "Learn how to build a webserver.",
  //   "/building-a-webserver/introduction/hello-world",
  // ),
  // #(
  //   "Deploy a webpage",
  //   "Deploy a static webpage",
  //   "/deploy/introduction/deploying",
  // ),
  ]
  let fixed = [
    #("/_redirects", <<redirects:utf8>>),
    #("/index.html", index.view(tours)),
    #("/index.js", <<index_js:utf8>>),
    #("/proxy.js", <<proxy_js:utf8>>),
    #("/auth/twitter/index.html", auth_page("twitter")),
    #("/auth/netlify/index.html", auth_page("netlify")),
  ]
  t.done(list.flatten([fixed, lessons, compiler_assets, static]))
}

fn load_tour_styles() {
  let tour_styles = [
    "/common.css", "/css/fonts.css", "/css/theme.css", "/css/layout.css",
    "/css/root.css", "/css/pages/everything.css", "/css/pages/lesson.css",
    "/css/code/syntax-highlight.css", "/css/code/color-schemes/atom-one.css",
  ]
  let tour_static_dir = "/language-tour/static"
  // needs to be a t.try_promise_map for proper use of t inside

  t.sequential(
    list.map(tour_styles, fn(path) {
      use bits <- t.do(t.read(tour_static_dir <> path))
      t.done(#(path, bits))
    }),
  )
}

fn read_compiler_assets() {
  let dir = "/ctrl/priv/vendor/wasm-compiler"
  // This is causing rollup to be unhappy
  // could read zipped??
  // use assets <- t.do(t.list(dir))
  let assets = [
    "/gleam_wasm_bg.wasm", "/gleam_wasm_bg.wasm.d.ts", "/gleam_wasm.d.ts",
    "/gleam_wasm.js",
  ]
  t.sequential(
    list.map(assets, fn(file) {
      use bits <- t.do(t.read(dir <> file))
      t.done(#("/wasm-compiler" <> file, bits))
    }),
  )
}

fn auth_page(service) {
  <<
    "<script>
  const channel = new BroadcastChannel('auth')
  channel.postMessage({service: '",
    service:utf8,
    "', redirect: window.location.href})
</script>",
  >>
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
