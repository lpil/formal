import formal/form.{type Form}
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/list
import gleam/string_tree.{type StringTree}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

/// This is the data to be extracted from the submitted form
type Signup {
  Signup(email: String, password: String, terms: Bool)
}

/// This function create a form that can extract the `Signup` data.
///
/// If the form is to be used with langauges other than English then the
/// `form.language` function can be used to supply an alternative error
/// translator.
///
fn signup_form() -> Form(Signup) {
  form.new({
    // The `parse_email` function validates the email format
    use email <- form.field("email", form.parse_email)

    // Terms and conditions have to be accepted, so we use `check_accepted`
    use terms <- form.field("terms", {
      form.parse_checkbox
      |> form.check_accepted
    })

    // Passwords have to be longer than 8 characters. More checks could be
    // added to enforce a stronger password.
    use password <- form.field("password", {
      form.parse_string
      |> form.check_string_length_more_than(8)
    })

    // The password must be entered twice, to prevent typos.
    // This field is only for validation, so the value is discarded.
    use _ <- form.field("confirm", {
      form.parse_string
      |> form.check_confirms(password)
    })

    form.success(Signup(email:, password:, terms:))
  })
}

/// The Wisp HTTP handler function for the application
pub fn handle_request(req: Request) -> Response {
  use req <- middleware(req)

  // GET requests: render the signup page, including a HTML form.
  // POST requests: handle the signup page form being submitted.
  case req.method {
    Get -> signup_page()
    Post -> signup_submit(req)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}

/// The signup page handler renders the HTML page and sends it to the browser.
fn signup_page() -> Response {
  // Create a new empty Form to render the HTML form with.
  // If the form is for updating something that already exists you may want to
  // use `form.add_string` or `form.add_values` to pre-fill some fields.
  let form = signup_form()

  signup_page_view(form)
  |> wisp.html_response(200)
}

/// The submission handler uses the form to extract and validate the data,
/// re-rendering the HTML form if there are errors, rending a success page
/// otherwise.
fn signup_submit(req: Request) -> Response {
  // Add the values from the HTTP request to the signup form
  use formdata <- wisp.require_form(req)
  let form = signup_form() |> form.add_values(formdata.values)

  case form.run(form) {
    // The form was valid! Do something with the data and render a success page
    // to the user.
    Ok(data) -> success_page_view(data) |> wisp.html_response(200)

    // The form was invalid. Render the HTML form again to show the errors to
    // the user.
    Error(form) -> signup_page_view(form) |> wisp.html_response(422)
  }
}

// Show a success page to the user
fn success_page_view(data: Signup) -> StringTree {
  html.div([], [
    html.h1([], [element.text("Welcome " <> data.email)]),
    html.p([], [element.text("You have successfully signed up!")]),
    html.p([], [html.a([attribute.href("/")], [element.text("Back")])]),
  ])
  |> page_layout_view
}

/// Render a HTML form. Some helper functions have been created to help
/// with rendering the label, input, and any errors.
/// In a real application you'd likely want more sophisticated form field
/// functions.
fn signup_page_view(form: Form(Signup)) -> StringTree {
  html.form([attribute.method("POST")], [
    field_input(form, "email", kind: "text", label: "Email"),
    field_input(form, "password", kind: "password", label: "Password"),
    field_input(form, "confirm", kind: "password", label: "Confirmation"),
    field_input(form, "terms", kind: "checkbox", label: "Accept terms"),
    html.div([], [html.input([attribute.type_("submit")])]),
  ])
  |> page_layout_view
}

/// Render a single HTML form field.
///
/// If the field already has a value then it is used as the HTML input value.
/// If the field has an error it is displayed.
///
fn field_input(
  form: Form(t),
  name name: String,
  kind kind: String,
  label label_text: String,
) -> Element(a) {
  let errors = form.field_error_messages(form, name)

  html.label([], [
    // The label text, for the user to read
    element.text(label_text),
    // The input, for the user to type into
    html.input([
      attribute.type_(kind),
      attribute.name(name),
      attribute.value(form.field_value(form, name)),
      case errors {
        [] -> attribute.none()
        _ -> attribute.aria_invalid("true")
      },
    ]),
    // Any errors presented below
    ..list.map(errors, fn(msg) { html.small([], [element.text(msg)]) })
  ])
}

// Boilerplate for the creation of a backend web app
pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

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

fn page_layout_view(content: Element(b)) -> StringTree {
  html.html([attribute.attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.meta([
        attribute.attribute("content", "width=device-width, initial-scale=1"),
        attribute.name("viewport"),
      ]),
      html.meta([
        attribute.attribute("content", "light dark"),
        attribute.name("color-scheme"),
      ]),
      html.title([], "Formal Wisp Example"),
      html.link([
        attribute.href(
          "https://cdn.jsdelivr.net/npm/@picocss/pico@2.1.1/css/pico.min.css",
        ),
        attribute.rel("stylesheet"),
      ]),
    ]),
    html.body([], [
      html.header([attribute.class("container")], [
        content,

        html.style(
          [],
          "
input[type=checkbox] {
  margin-left: 1em;
}

input[type=checkbox] + small {
  margin-top: 0;
}
",
        ),
      ]),
    ]),
  ])
  |> element.to_document_string_tree
}
