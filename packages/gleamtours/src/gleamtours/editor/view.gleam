import gleam/int
import gleam/list
import gleam/string
import glexer
import glexer/token as t
import lustre/attribute as a
import lustre/element.{text} as _
import lustre/element/html as h
import lustre/event as e
import plinth/browser/document
import plinth/browser/element
import plinth/browser/event
import plinth/browser/window

// https://css-tricks.com/creating-an-editable-textarea-that-supports-syntax-highlighted-code/
const monospace = "ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,\"Liberation Mono\",\"Courier New\",monospace"

const pre_id = "highlighting-underlay"

pub fn render(code, on_update) {
  h.div(
    [
      a.style([
        #("position", "relative"),
        #("font-family", monospace),
        #("width", "100%"),
        #("height", "100%"),
        #("overflow", "hidden"),
      ]),
    ],
    [
      h.pre(
        [
          a.id(pre_id),
          a.style([
            #("position", "absolute"),
            #("top", "0"),
            #("bottom", "0"),
            #("left", "0"),
            #("right", "0"),
            #("margin", "0 !important"),
            #("white-space", "pre-wrap"),
            #("word-wrap", "break-word"),
            #("overflow", "auto"),
          ]),
        ],
        highlight(code),
      ),
      h.textarea(
        [
          a.style([
            #("display", "block"),
            // z-index can cause the highlight to be lot behind other containers. 
            // make this position relative so stacked with absolute elements but do not move.
            #("position", "relative"),
            #("width", "100%"),
            #("height", "100%"),
            #("padding", "0 !important"),
            #("margin", "0 !important"),
            #("border", "0"),
            #("color", "transparent"),
            #("font-size", "1em"),
            #("background-color", "transparent"),
            #("outline", "2px solid transparent"),
            #("outline-offset", "2px"),
            #("caret-color", "black"),
          ]),
          a.attribute("spellcheck", "false"),
          a.attribute("rows", int.to_string(10)),
          e.on_input(on_update),
          // stops navigation
          e.on("keydown", fn(event) {
            e.stop_propagation(event)
            Error([])
          }),
          e.on("scroll", fn(event) {
            let assert Ok(event) = event.cast_event(event)
            let target = event.target(event)
            window.request_animation_frame(fn(_) {
              let assert Ok(target) = element.cast(target)
              let scroll_top = element.scroll_top(target)
              let scroll_left = element.scroll_left(target)
              let assert Ok(pre) = document.query_selector("#" <> pre_id)
              element.set_scroll_top(pre, scroll_top)
              element.set_scroll_left(pre, scroll_left)
              Nil
            })

            Error([])
          }),
        ],
        code,
      ),
    ],
  )
}

fn token_to_string(token) {
  case token {
    // Literals
    t.Name(value) -> #("", value)
    t.UpperName(value) -> #("", value)
    t.DiscardName(value) -> #("", value)
    t.Int(value) -> #("", value)
    t.Float(value) -> #("", value)
    t.String(value) -> #("string", "\"" <> value <> "\"")

    // Keywords
    t.As -> #("keyword", "as")
    t.Assert -> #("keyword", "assert")
    t.Auto -> #("keyword", "auto")
    t.Case -> #("keyword", "case")
    t.Const -> #("keyword", "const")
    t.Delegate -> #("keyword", "delegate")
    t.Derive -> #("keyword", "derive")
    t.Echo -> #("keyword", "echo")
    t.Else -> #("keyword", "else")
    t.Fn -> #("keyword", "fn")
    t.If -> #("keyword", "if")
    t.Implement -> #("keyword", "implement")
    t.Import -> #("keyword", "import")
    t.Let -> #("keyword", "let")
    t.Macro -> #("keyword", "macro")
    t.Opaque -> #("keyword", "opaque")
    t.Panic -> #("keyword", "panic")
    t.Pub -> #("keyword", "pub")
    t.Test -> #("keyword", "test")
    t.Todo -> #("keyword", "todo")
    t.Type -> #("keyword", "type")
    t.Use -> #("keyword", "use")

    // Groupings
    t.LeftParen -> #("punctuation", "(")
    t.RightParen -> #("punctuation", ")")
    t.LeftBrace -> #("punctuation", "{")
    t.RightBrace -> #("punctuation", "}")
    t.LeftSquare -> #("punctuation", "[")
    t.RightSquare -> #("punctuation", "]")

    // Int Operators
    t.Plus -> #("operator", "+")
    t.Minus -> #("operator", "-")
    t.Star -> #("operator", "*")
    t.Slash -> #("operator", "/")
    t.Less -> #("operator", "<")
    t.Greater -> #("operator", ">")
    t.LessEqual -> #("operator", "<=")
    t.GreaterEqual -> #("operator", ">=")
    t.Percent -> #("operator", "%")

    // Float Operators
    t.PlusDot -> #("operator", "+.")
    t.MinusDot -> #("operator", "-.")
    t.StarDot -> #("operator", "*.")
    t.SlashDot -> #("operator", "/.")
    t.LessDot -> #("operator", "<.")
    t.GreaterDot -> #("operator", ">.")
    t.LessEqualDot -> #("operator", "<=.")
    t.GreaterEqualDot -> #("operator", ">=.")

    // String Operators
    t.LessGreater -> #("operator", "<>")

    // Other Punctuation
    t.At -> #("", "@")
    t.Colon -> #("", ":")
    t.Comma -> #("", ",")
    t.Hash -> #("", "#")
    t.Bang -> #("", "!")
    t.Equal -> #("operator", "=")
    t.EqualEqual -> #("operator", "==")
    t.NotEqual -> #("operator", "!=")
    t.VBar -> #("", "|")
    t.VBarVBar -> #("operator", "||")
    t.AmperAmper -> #("operator", "&&")
    t.LessLess -> #("operator", "<<")
    t.GreaterGreater -> #("operator", ">>")
    t.Pipe -> #("operator", "|>")
    t.Dot -> #("", ".")
    t.DotDot -> #("", "..")
    t.LeftArrow -> #("operator", "<-")
    t.RightArrow -> #("operator", "->")
    t.EndOfFile -> #("", "")

    // Extra
    t.CommentNormal(content) -> #("comment", "//" <> content)
    t.CommentDoc(value) -> #("comment", "///" <> value)
    t.CommentModule(content) -> #("comment", "////" <> content)

    // Invalid code tokens
    t.Space(value) -> #("", value)
    t.UnterminatedString(value) -> #("", value)
    t.UnexpectedGrapheme(value) -> #("", value)
  }
}

fn highlight(code) {
  let tokens =
    code
    |> glexer.new()
    |> glexer.lex()

  let #(current, buffer, acc) =
    list.fold(tokens, #("", "", []), fn(state, token) {
      let #(current, buffer, acc) = state
      let #(token, _) = token
      let #(class, printed) = token_to_string(token)
      let #(buffer, acc) = case class == current {
        True -> #(string.append(buffer, printed), acc)
        False -> #(printed, [wrap(buffer, current), ..acc])
      }
      let state = #(class, buffer, acc)
      state
    })
  case buffer {
    "" -> acc
    _ -> [wrap(buffer, current), ..acc]
  }
  // needs one final empty space
  |> list.append([text(" ")], _)
  |> list.reverse
}

fn wrap(content, class) {
  case class {
    "" -> text(content)
    _ -> h.span([a.class("token " <> class)], [text(content)])
  }
}
