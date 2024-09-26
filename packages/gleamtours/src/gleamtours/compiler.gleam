import filepath
import gleam/bit_array
import gleam/dict
import gleam/dynamic
import gleam/result
import gleam/string
import gleamtours/compiler/prelude.{prelude}
import midas/browser/gleam
import midas/js/run as r
import plinth/browser/window
import snag

pub type State {
  Compiled(warnings: List(String))
  Errored(reason: String)
  Dirty
}

pub type Compiler {
  Compiler(project: gleam.Project, code: String, state: State)
}

pub fn start(code, deps_src) {
  use project <- r.await(gleam.new_project() |> r.map_error(snag.new))
  use deps <- r.await(window.import_(deps_src) |> r.map_error(snag.new))
  let assert Ok(deps) =
    dynamic.field("default", dynamic.dict(dynamic.string, dynamic.string))(deps)

  dict.each(deps, fn(path, content) {
    let path = filepath.join("/src", path)
    gleam.write_file(project, path, content)
  })
  gleam.write_module(project, "main", code)
  let state = Dirty
  let compiler = Compiler(project, code, state)
  let compiler = compile(compiler)
  r.done(compiler)
}

pub fn code_change(compiler, new) {
  let Compiler(project: project, ..) = compiler
  gleam.write_module(project, "main", new)

  let state = Dirty
  Compiler(..compiler, code: new, state: state)
}

pub fn compile(compiler) {
  let Compiler(project: project, ..) = compiler

  gleam.reset_warnings(project)
  let state = case gleam.compile_package(project, "javascript") {
    Ok(Nil) -> Compiled(gleam.take_warnings(project))
    Error(reason) -> Errored(reason)
  }
  Compiler(..compiler, state: state)
}

fn compile_dirty(compiler) {
  let Compiler(state: state, ..) = compiler
  case state {
    Dirty -> compile(compiler)
    _ -> compiler
  }
}

pub fn read_output(compiler, module) {
  let Compiler(project: project, ..) = compile_dirty(compiler)

  case module {
    "gleam_prelude.mjs" -> Ok(prelude)
    "gleam_stdlib.mjs" -> read_file(project, "/src/" <> module)
    _ -> {
      let path = "/build/" <> module
      case read_file(project, path) {
        Ok(content) -> Ok(content)
        Error(_) -> read_file(project, "/src/" <> module)
      }
    }
  }
}

fn read_file(project, path) {
  use bytes <- result.try(
    gleam.read_file_bytes(project, path)
    |> result.map_error(snag.new)
    |> snag.context(
      string.concat(["Failed to read file from compiler at ", path]),
    ),
  )
  use code <- result.try(
    bit_array.to_string(bytes)
    |> result.replace_error(snag.new("Not utf8"))
    |> snag.context(
      string.concat(["Failed to convert file from compiler at ", path]),
    ),
  )
  Ok(code)
}
