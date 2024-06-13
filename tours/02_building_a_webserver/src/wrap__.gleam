import main
import pojo/http/request
import pojo/http/response

// is there a dynamic bits

pub fn handle(request) {
  let assert Ok(request) = request.decoder(request)
  let response = main.handle(request)
  response.to_json(response)
}
