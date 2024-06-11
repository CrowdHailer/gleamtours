import midas/sdk/netlify
import midas/task as t

pub const app = netlify.App(
  "-YQebIC-PkC4ANX-5OC_qdO3cW9x8RAVoEzzqL6Ssu8",
  "https://gleamtours.com/auth/netlify",
)

const site_id = "4b271125-3f12-40a9-b4bc-ccf5e82879dd"

fn build() {
  let files = [#("index.html", <<"hi":utf8>>)]
  files
}

pub fn run() {
  use token <- t.do(netlify.authenticate(app))
  use Nil <- t.do(t.log("Authenticated"))

  use response <- t.do(netlify.deploy_site(token, site_id, build()))
  use Nil <- t.do(t.log("Site deployed: " <> response))

  t.Done("Ok")
}
