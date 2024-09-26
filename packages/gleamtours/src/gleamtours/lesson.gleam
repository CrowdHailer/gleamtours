import filepath
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamicx
import gleam/fetch
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response
import gleam/io
import gleam/javascript as js
import gleam/javascript/promise
import gleam/javascript/promisex
import gleam/json
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
import midas/browser/gleam
import midas/browser/rollup
import platforms/browser/windows
import plinth/browser/broadcast_channel
import plinth/browser/document
import plinth/browser/element
import plinth/browser/message
import plinth/browser/window.{type Window}
import plinth/javascript/global
import pojo/http/request as prequest
import pojo/http/response as presponse
import pojo/http/utils
import pojo/result as presult
import snag.{type Result}
import tour

pub fn page(lesson) {
  tour.lesson_page_render(lesson)
}

fn environment() {
  case uri.parse(window.location()) {
    Ok(Uri(path: "/building-a-webserver" <> _, ..)) -> WebServer
    Ok(Uri(path: "/deploy" <> _, ..)) -> Task
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
  Task
}

pub type App {
  Preparing(code: String, compiler: Remote(Compiler), proxy: Remote(Proxy))
  App(
    compiler: Compiler,
    debounce: fn() -> Nil,
    proxy: Proxy,
    opened: Option(Window),
    environment: Environment,
    run: Option(List(String)),
  )
}

pub type Message {
  CompilerLoaded(Result(Compiler), fn() -> Nil)
  ProxyLoaded(Result(Proxy), fn() -> Nil)
  ProxiedRequest(id: Int, project_id: String, request: Request(BitArray))

  ChooseEnvironment(Environment)
  CodeChange(String)
  Timeout
  Execute
  RunLog(String)
  RunDone(String)
}

fn handle_as_webserver(compiler, client_id, project_id, request) {
  case project_id {
    "0" -> {
      // Needs to be HTML only this gets rather circular so running needs to not end up here
      let request = dynamic.from(prequest.to_json(request))
      let work =
        gleam.run_with_client(client_id, "1", "wrap__", "handle", request)
      use r <- promise.map(work)
      case r {
        Ok(value) -> {
          let decoded = presponse.decoder(value)
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

fn handle_as_script(compiler, project_id, request) {
  case project_id {
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
    _ -> panic as "only 0 is valid project it"
  }
}

pub fn update(app, message) {
  case app, message {
    Preparing(proxy: Loaded(proxy), ..), CompilerLoaded(Ok(compiler), dbounce)
    | Preparing(compiler: Loaded(compiler), ..), ProxyLoaded(Ok(proxy), dbounce)
    -> #(
      App(compiler, dbounce, proxy, None, environment(), None),
      effect.none(),
    )
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
    App(compiler, _debouncer, proxy, _opened, environment, _run),
      ProxiedRequest(caller_id, project_id, request)
    -> #(
      app,
      effect.from(fn(_dispatch) {
        let Proxy(service_worker: service_worker, ..) = proxy

        use response <- promisex.aside(case environment {
          WebServer ->
            handle_as_webserver(compiler, proxy.client_id, project_id, request)
          WebApp -> handle_as_webapp(compiler, project_id, request.path)
          Task -> handle_as_script(compiler, project_id, request)
        })
        proxy.send_response(service_worker, caller_id, Ok(response))
      }),
    )

    App(compiler, debouncer, proxy, opened, _old, run), ChooseEnvironment(new) -> {
      #(App(compiler, debouncer, proxy, opened, new, run), effect.none())
    }
    App(compiler, debouncer, proxy, opened, environment, run), CodeChange(new) -> {
      let compiler = compiler.code_change(compiler, new)
      #(
        App(compiler, debouncer, proxy, opened, environment, run),
        effect.from(fn(_dispatch) { debouncer() }),
      )
    }
    App(compiler, debouncer, proxy, opened, environment, run), Timeout -> {
      let compiler = compiler.compile(compiler)
      #(
        App(compiler, debouncer, proxy, opened, environment, run),
        effect.none(),
      )
    }
    App(compiler, debouncer, proxy, opened, environment, run), Execute -> {
      let open = open_sandbox(
        _,
        compiler,
        debouncer,
        proxy,
        opened,
        environment,
        run,
      )
      case environment {
        WebServer -> open("/sandbox/server/" <> proxy.client_id <> "/0")
        WebApp -> open(proxy.spa_path(proxy))
        Task -> {
          let app =
            App(compiler, debouncer, proxy, opened, environment, Some([]))
          #(
            app,
            effect.from(fn(dispatch) {
              let work =
                gleam.run_with_client(
                  proxy.client_id,
                  "1",
                  "wrap__",
                  "run",
                  dynamic.from(json.string("s")),
                )
              promise.map(work, fn(x) {
                let assert Ok(return) = x
                run_script(compiler, return, dispatch)
              })
              Nil
            }),
          )
        }
      }
    }
    App(compiler, debouncer, proxy, opened, environment, run), RunDone(message)
    | App(compiler, debouncer, proxy, opened, environment, run), RunLog(message)
    -> {
      let run = case run {
        None -> Some([message])
        Some(messages) -> Some([message, ..messages])
      }
      let app = App(compiler, debouncer, proxy, opened, environment, run)
      #(app, effect.none())
    }
    _, _ -> {
      io.debug(#(app, message))
      #(app, effect.none())
    }
  }
}

fn run_script(compiler, return, dispatch) {
  io.debug(return)
  let assert Ok(Serialized(label, payload, then)) =
    dynamic.decode3(
      Serialized,
      dynamic.field("0", dynamic.string),
      dynamic.field("1", is_ok),
      dynamic.field("2", is_ok),
    )(return)

  case label {
    "Bundle" -> {
      let decoder =
        dynamic.decode2(
          fn(a, b) { #(a, b) },
          dynamic.field("module", dynamic.string),
          dynamic.field("function", dynamic.string),
        )
      let assert Ok(#(module, function)) = decoder(dynamic.from(payload))
      use out <- promise.await(
        rollup.bundle(
          module,
          function,
          fn(source, importer) {
            let assert Ok(source) =
              filepath.expand(filepath.join(
                filepath.directory_name(importer),
                source,
              ))
            source
          },
          fn(module) {
            let assert Ok(content) = compiler.read_output(compiler, module)
            content
          },
        ),
      )
      let next =
        then(dynamic.from(presult.to_json(json.string, json.string)(out)))
      run_script(compiler, dynamic.from(next), dispatch)
    }
    "Follow" -> {
      let assert Ok(path) = dynamic.string(dynamic.from(payload))
      // let assert Ok(popup) = browser.open(path)
      let assert Ok(popup) = windows.open(path, #(600, 700))
      use redirect <- promise.await(
        promise.new(fn(resolve) {
          let assert Ok(channel) = broadcast_channel.new("auth")
          broadcast_channel.on_message(channel, fn(message) {
            dynamic.field("redirect", dynamic.string)(
              dynamic.from(message.data(message)),
            )
            |> resolve()
          })
        }),
      )
      window.close(popup)
      let assert Ok(redirect) = redirect
      let next = then(dynamic.from(redirect))
      run_script(compiler, dynamic.from(next), dispatch)
    }
    "Fetch" -> {
      let assert Ok(request) = prequest.decoder(dynamic.from(payload))
      let assert "https://" <> rest = uri.to_string(request.to_uri(request))
      let location = window.location()
      io.debug(location)
      io.debug("-----")
      let #(scheme, host) = case location {
        "https://gleamtours.com" <> _ -> #(http.Https, "gleamtours.com")
        "http://localhost:8080" <> _ -> #(http.Http, "localhost:8080")
        _ -> panic as { "unexpected location: " <> location }
      }
      let request =
        Request(
          ..request,
          scheme: scheme,
          host: host,
          port: None,
          query: None,
          path: "/proxy/" <> rest,
        )

      use response <- promise.await(fetch.send_bits(request))
      use response <- promise.await(case response {
        Ok(response) -> fetch.read_bytes_body(response)
        Error(reason) -> promise.resolve(Error(reason))
      })
      let response =
        presult.to_json(presponse.to_json, fn(reason) {
          json.string(string.inspect(reason))
        })(response)
      let next = then(dynamic.from(response))
      run_script(compiler, dynamic.from(next), dispatch)
    }
    "Log" -> {
      let assert Ok(message) = dynamic.string(dynamic.from(payload))
      dispatch(RunLog(message))
      let next = then(dynamic.from(Nil))
      run_script(compiler, dynamic.from(next), dispatch)
    }
    "Zip" -> {
      let assert Ok(files) =
        dynamic.list(dynamic.decode2(
          fn(a, b) { #(a, b) },
          dynamic.field("name", dynamic.string),
          dynamic.field("content", utils.body_decoder),
        ))(dynamic.from(payload))
      todo as "Zip unsupported in this environment"
      // use zipped <- promise.await(zip_js.zip(files))
      // let zipped = utils.body_to_json(zipped)
      // let next = then(dynamic.from(zipped))
      // run_script(compiler, dynamic.from(next), dispatch)
    }
    "Done" -> {
      let final = case dynamic.string(dynamic.from(payload)) {
        Ok(final) -> final
        Error(_) -> string.inspect(payload)
      }
      dispatch(RunDone(final))
      promise.resolve(Ok(payload))
    }
    "Abort" -> {
      let final = case dynamic.string(dynamic.from(payload)) {
        Ok(final) -> final
        Error(_) -> string.inspect(payload)
      }
      dispatch(RunDone("ERROR: " <> final))
      promise.resolve(Error(Nil))
    }
    _ -> {
      io.debug(#(label, payload))
      panic as "wat"
    }
  }
}

fn is_ok(v) {
  Ok(dynamicx.unsafe_coerce(v))
}

pub type Serialized {
  Serialized(String, json.Json, fn(Dynamic) -> Serialized)
}

fn open_sandbox(path, compiler, debouncer, proxy, opened, environment, run) {
  let app = case opened {
    None -> {
      let assert Ok(sandbox) = windows.open(path, #(800, 800))
      // state overrides to compiled to close iframe
      let compiler = Compiler(..compiler, state: compiler.Compiled([]))
      App(compiler, debouncer, proxy, Some(sandbox), environment, run)
    }
    Some(sandbox) -> {
      case window.closed(sandbox) {
        True -> {
          let assert Ok(sandbox) = windows.open(path, #(800, 800))
          // state overrides to compiled to close iframe
          let compiler = Compiler(..compiler, state: compiler.Compiled([]))
          App(compiler, debouncer, proxy, Some(sandbox), environment, run)
        }
        False -> {
          window.set_location(sandbox, path)
          // window.reload_of(sandbox)
          window.focus(sandbox)
          App(compiler, debouncer, proxy, opened, environment, run)
        }
      }
    }
  }
  #(app, effect.none())
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
    App(compiler: compiler, run: run, ..) -> {
      let Compiler(code: code, state: state, ..) = compiler
      [
        h.section([a.id("editor")], [editor(code, CodeChange)]),
        h.aside([a.id("output")], case run, state {
          Some(items), _ -> [
            h.pre(
              [],
              list.map(list.reverse(items), fn(item) { h.p([], [text(item)]) }),
            ),
          ]
          None, compiler.Compiled(warnings) ->
            list.map(warnings, fn(warning) {
              h.pre([a.class("warning")], [text(warning)])
            })
          None, compiler.Errored(reason) -> [
            h.pre([a.class("error")], [text(reason)]),
          ]
          None, compiler.Dirty -> []
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
