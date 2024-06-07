import gleam/bit_array
import gleam/dynamic
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/io
import gleam/javascript as js
import gleam/javascript/promise
import gleam/javascript/promisex
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri.{Uri}
import gleamtours/compiler.{type Compiler, Compiler}
import gleamtours/editor/view
import gleamtours/sandbox/proxy.{type Proxy, Proxy}
import lustre
import lustre/attribute as a
import lustre/effect
import lustre/element.{text} as _
import lustre/element/html as h
import lustre/event
import midas/web/gleam
import platforms/browser/windows
import plinth/browser/document
import plinth/browser/element
import plinth/browser/window.{type Window}
import plinth/javascript/global
import snag.{type Result}
import tour

pub fn page(lesson) {
  tour.lesson_page_render(lesson)
}

fn environment() {
  case uri.parse(window.location()) {
    Ok(Uri(path: "/webserver" <> _, ..)) -> WebServer
    _ -> WebApp
  }
}

fn editor(code, on_change) {
  h.div(
    [a.class("codeflask"), a.style([#("padding", "0.5em"), #("height", "95%")])],
    [
      view.render(code, on_change),
      h.div([a.style([#("text-align", "center")])], [
        // h.button([event.on_click(Run)], [text("Run")]),
        // h.select(
        //   [
        //     event.on_input(fn(selected) {
        //       case selected {
        //         "client" -> WebApp
        //         "server" -> WebServer
        //         _ -> panic as "should never be other type"
        //       }
        //       |> ChooseEnvironment
        //     }),
        //   ],
        //   [
        //     h.option([a.selected(environment == WebApp)], "client"),
        //     h.option([a.selected(environment == WebServer)], "server"),
        //   ],
        // ),
        h.button(
          [
            event.on_click(Execute),
            a.style([
              #("background-color", "var(--color-navbar-background)"),
              #("padding", "0.5em 1em"),
              #("border-width", "1px"),
            ]),
          ],
          [text("Run")],
        ),
      ]),
    ],
  )
}

pub type Remote(resource) {
  Loading
  Loaded(resource)
  Failed(snag.Snag)
}

pub type Environment {
  WebServer
  WebApp
}

pub type App {
  Preparing(code: String, compiler: Remote(Compiler), proxy: Remote(Proxy))
  App(
    compiler: Compiler,
    debounce: fn() -> Nil,
    proxy: Proxy,
    opened: Option(Window),
    environment: Environment,
  )
}

pub type Message {
  CompilerLoaded(Result(Compiler), fn() -> Nil)
  ProxyLoaded(Result(Proxy), fn() -> Nil)
  ProxiedRequest(id: Int, project_id: String, request: Request(BitArray))

  ChooseEnvironment(Environment)
  CodeChange(String)
  Timeout
  // This automatically executes in a popup
  Execute
  // Open separate toggle fn
}

fn handle_as_webserver(compiler, client_id, project_id, request) {
  case project_id {
    "0" -> {
      // Needs to be HTML only this gets rather circular so running needs to not end up here
      let request = dynamic.from(proxy.json_request(request))
      let work =
        gleam.run_with_client(client_id, "1", "wrap__", "handle", request)
      use r <- promise.map(work)
      case r {
        Ok(value) -> {
          let decoded = proxy.response_decoder(value)
          case decoded {
            Ok(response) -> {
              response
              |> response.prepend_header("cache-control", "no-cache")
            }
            Error(reason) -> {
              response.new(200)
              |> response.prepend_header("content-type", "text/plain")
              |> response.set_body(
                bit_array.from_string(string.inspect(reason)),
              )
              |> response.prepend_header("cache-control", "no-cache")
            }
          }
        }
        Error(reason) -> {
          io.debug(reason)
          response.new(200)
          |> response.prepend_header("content-type", "text/plain")
          |> response.set_body(bit_array.from_string(string.inspect(reason)))
          |> response.prepend_header("cache-control", "no-cache")
        }
      }
    }

    "1" -> {
      let request.Request(path: path, ..) = request
      case compiler.read_output(compiler, path) {
        Ok(code) -> {
          response.new(200)
          |> response.prepend_header("content-type", "text/javascript")
          |> response.set_body(bit_array.from_string(code))
          |> response.prepend_header("cache-control", "no-cache")
        }
        Error(reason) -> {
          response.new(404)
          |> response.set_body(bit_array.from_string(string.inspect(reason)))
          |> response.prepend_header("cache-control", "no-cache")
        }
      }
      |> promise.resolve()
    }
    _ -> panic as "unknown project id"
  }
}

fn handle_as_webapp(compiler, project_id, path) {
  case project_id {
    "0" -> {
      let p = path
      let js = string.ends_with(p, ".mjs") || string.ends_with(p, ".js")
      case js {
        False -> {
          let page =
            "<!DOCTYPE html>
<html>
<head>
  <script>
  window.addEventListener('error', (event) => {
    let {fn, line, message} = event.error
    let rendered = '<div style=\"display: flex; flex-direction: column; align-items: center; min-height: 100vh; margin: 0; justify-content: center; background-color: #db7093; font-weight: bold; color: white;\">'
    if (message) {
      rendered += '<h1>Something went wrong</h1><p>' + message + '<br/>in fn: ' + fn + '<br/>on line: ' + line + '<br/><br/>Refresh page to start over.</p>'
    } else {
      rendered += '<p>' + event.error + '</p>'
    }
    rendered += '</div>'
    document.body.innerHTML = rendered
  })
  </script>
</head>
<body style=\"margin: 0;\">
  <div>
  </div>
  <script type=\"module\">import { main } from \"/main.mjs\"; main()</script>
</body>
</html>"
          // window.addEventListener("unhandledrejection", (content) => {
          //   console.log("promise content: ", content);
          // });
          response.new(200)
          |> response.prepend_header("content-type", "text/html")
          |> response.set_body(bit_array.from_string(page))
          |> response.prepend_header("cache-control", "no-cache")
          |> promise.resolve()
        }
        True -> {
          case compiler.read_output(compiler, path) {
            Ok(code) -> {
              response.new(200)
              |> response.prepend_header("content-type", "text/javascript")
              |> response.set_body(bit_array.from_string(code))
              |> response.prepend_header("cache-control", "no-cache")
            }
            Error(reason) -> {
              response.new(404)
              |> response.set_body(
                bit_array.from_string(string.inspect(reason)),
              )
              |> response.prepend_header("cache-control", "no-cache")
            }
          }
          |> promise.resolve()
        }
      }
    }
    _ -> panic as "only 0 is valid project it"
  }
}

pub fn update(app, message) {
  case app, message {
    Preparing(proxy: Loaded(proxy), ..), CompilerLoaded(Ok(compiler), dbounce)
    | Preparing(compiler: Loaded(compiler), ..), ProxyLoaded(Ok(proxy), dbounce)
    -> #(App(compiler, dbounce, proxy, None, environment()), effect.none())
    Preparing(code: code, proxy: proxy, ..), CompilerLoaded(Ok(compiler), _) -> {
      let state = Preparing(code, Loaded(compiler), proxy)
      #(state, effect.none())
    }
    Preparing(code: code, proxy: proxy, ..), CompilerLoaded(Error(reason), _) -> {
      let state = Preparing(code, Failed(reason), proxy)
      #(state, effect.none())
    }
    Preparing(code: code, compiler: compiler, ..), ProxyLoaded(Ok(proxy), _) -> {
      // this only shows if proxy loads last. 
      io.println("Registered as client: " <> proxy.client_id <> " with proxy")
      let state = Preparing(code, compiler, Loaded(proxy))
      #(state, effect.none())
    }
    Preparing(code: code, compiler: compiler, ..), ProxyLoaded(Error(reason), _)
    -> {
      let state = Preparing(code, compiler, Failed(reason))
      #(state, effect.none())
    }

    // -------------------
    App(compiler, _debouncer, proxy, _opened, environment),
      ProxiedRequest(caller_id, project_id, request)
    -> #(
      app,
      effect.from(fn(_dispatch) {
        let Proxy(service_worker: service_worker, ..) = proxy

        use response <- promisex.aside(case environment {
          WebServer ->
            handle_as_webserver(compiler, proxy.client_id, project_id, request)
          WebApp -> handle_as_webapp(compiler, project_id, request.path)
        })
        proxy.send_response(service_worker, caller_id, Ok(response))
      }),
    )

    App(compiler, debouncer, proxy, opened, _old), ChooseEnvironment(new) -> {
      #(App(compiler, debouncer, proxy, opened, new), effect.none())
    }
    App(compiler, debouncer, proxy, opened, environment), CodeChange(new) -> {
      let compiler = compiler.code_change(compiler, new)
      #(
        App(compiler, debouncer, proxy, opened, environment),
        effect.from(fn(_dispatch) { debouncer() }),
      )
    }
    App(compiler, debouncer, proxy, opened, environment), Timeout -> {
      let compiler = compiler.compile(compiler)
      #(App(compiler, debouncer, proxy, opened, environment), effect.none())
    }
    App(compiler, debouncer, proxy, opened, environment), Execute -> {
      let path = case environment {
        WebServer -> "/sandbox/server/" <> proxy.client_id <> "/0"
        WebApp -> proxy.spa_path(proxy)
      }

      let app = case opened {
        None -> {
          let assert Ok(sandbox) = windows.open(path, #(800, 800))
          // state overrides to compiled to close iframe
          let compiler = Compiler(..compiler, state: compiler.Compiled([]))
          App(compiler, debouncer, proxy, Some(sandbox), environment)
        }
        Some(sandbox) -> {
          case window.closed(sandbox) {
            True -> {
              let assert Ok(sandbox) = windows.open(path, #(800, 800))
              // state overrides to compiled to close iframe
              let compiler = Compiler(..compiler, state: compiler.Compiled([]))
              App(compiler, debouncer, proxy, Some(sandbox), environment)
            }
            False -> {
              window.set_location(sandbox, path)
              // window.reload_of(sandbox)
              window.focus(sandbox)
              app
            }
          }
        }
      }
      #(app, effect.none())
    }
    _, _ -> {
      io.debug(#(app, message))
      #(app, effect.none())
    }
  }
}

fn resource(resource) {
  case resource {
    Loading -> text("loading")
    Loaded(_) -> text("ready")
    Failed(reason) -> h.pre([], [text(snag.pretty_print(reason))])
  }
}

pub fn view(app) {
  h.section([a.id("right")], case app {
    Preparing(code, compiler, proxy) -> [
      h.section([a.id("editor")], [editor(code, CodeChange)]),
      h.aside([a.id("output")], [
        h.div([], [text("compiler "), resource(compiler)]),
        h.div([], [text("proxy "), resource(proxy)]),
      ]),
    ]
    App(compiler, _debounce, ..) -> {
      let Compiler(code: code, state: state, ..) = compiler
      [
        h.section([a.id("editor")], [editor(code, CodeChange)]),
        h.aside([a.id("output")], case state {
          compiler.Compiled(warnings) ->
            list.map(warnings, fn(warning) {
              h.pre([a.class("warning")], [text(warning)])
            })
          compiler.Errored(reason) -> [
            h.pre([a.class("error")], [text(reason)]),
          ]
          compiler.Dirty -> []
        }),
      ]
    }
  })
}

pub fn app() {
  let assert Ok(container) = document.query_selector("#code")
  let initial = element.inner_text(container)
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#right", initial)
  Nil
}

fn new_debouncer(d) {
  let ref = js.make_reference(None)
  fn() {
    case js.dereference(ref) {
      None -> Nil
      Some(timer) -> global.clear_timeout(timer)
    }
    let timer =
      global.set_timeout(200, fn() {
        d(Timeout)
        Nil
      })
    js.set_reference(ref, Some(timer))
    Nil
  }
}

fn init(initial) {
  let state = Preparing(initial, Loading, Loading)
  let assert Ok(url) = uri.parse(window.location())
  let assert ["", root, ..] = string.split(url.path, "/")
  let deps_path = "/" <> root <> "/deps.js"
  #(
    state,
    effect.from(fn(d) {
      let debouncer = new_debouncer(d)
      promise.map(compiler.start(initial, deps_path), fn(compiler) {
        d(CompilerLoaded(compiler, debouncer))
      })
      promise.map(
        proxy.install(fn(id, project_id, request) {
          d(ProxiedRequest(id, project_id, request))
        }),
        fn(proxy) { d(ProxyLoaded(proxy, debouncer)) },
      )
      Nil
    }),
  )
}
