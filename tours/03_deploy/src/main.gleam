import gleam/json
import midas/task

pub fn run() {
  task.Follow("example.com", fn(_) { task.Done(json.null()) })
}
