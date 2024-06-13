import gleam/io
import midas/task as t

pub fn app() {
  io.println("Hello world!")
}

pub fn run() {
  use src <- t.do(t.bundle("main", "app"))
  use Nil <- t.do(t.log(src))
  t.Done(Nil)
}
