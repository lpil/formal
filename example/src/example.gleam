import formal/form.{type Form}
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/string
import gleam/string_builder.{type StringBuilder}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

type Submission {
  Submission(name: String, level: Int)
}

pub fn handle_request(req: Request) -> Response {
  use req <- middleware(req)

  // For GET requests, render a new form
  // For POST requests process the data from a submitted form
  case req.method {
    Get -> new_form()
    Post -> submit_form(req)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}

fn new_form() -> Response {
  // Create a new empty Form to render the HTML form with.
  // If the form is for updating something that already exists you may want to
  // use `form.initial_values` to pre-fill some fields.
  let form = form.new()

  render_form(form)
  |> wisp.html_response(200)
}

fn submit_form(req: Request) -> Response {
  use formdata <- wisp.require_form(req)

  // Extract the data from the submitted form
  let result =
    form.decoding({
      use name <- form.parameter
      use level <- form.parameter
      Submission(name: name, level: level)
    })
    |> form.with_values(formdata.values)
    |> form.field("name", form.string |> form.and(form.must_not_be_empty))
    |> form.field("level", form.int)
    |> form.finish

  case result {
    // The form was valid! Do something with the data and render a page to the user
    Ok(data) -> {
      string.inspect(data)
      |> string_builder.from_string
      |> wisp.html_response(200)
    }

    // The form was invalid. Render the HTML form again with the errors
    Error(form) -> {
      render_form(form)
      |> wisp.html_response(422)
    }
  }
}

/// Render a HTML form for a Form object using Lustre
fn render_form(form: Form) -> StringBuilder {
  html.form([attribute.method("POST")], [
    form_field(form, name: "name", kind: "text", title: "Name"),
    form_field(form, name: "level", kind: "number", title: "Level"),
    html.div([], [html.input([attribute.type_("submit")])]),
  ])
  |> element.to_document_string_builder
}

/// Render a single HTML form field.
///
/// If the field already has a value then it is used as the HTML input value.
/// If the field has an error it is displayed.
///
fn form_field(
  form: Form,
  name name: String,
  kind kind: String,
  title title: String,
) -> Element(a) {
  // Make an element containing the error message, if there is one.
  let error_element = case form.field_state(form, name) {
    Ok(_) -> element.none()
    Error(message) ->
      html.div([attribute.class("error")], [element.text(message)])
  }

  // Render a label and an input using the error and the value from the form.
  // In a real program you likely want to add attributes for client side
  // validation and for accessibility.
  html.label([], [
    html.div([], [element.text(title)]),
    error_element,
    html.input([
      attribute.type_(kind),
      attribute.name(name),
      attribute.value(form.value(form, name)),
    ]),
  ])
}

//
// Boilerplate for the creation of a backend web app
//

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

pub fn middleware(
  req: wisp.Request,
  handler: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  handler(req)
}
