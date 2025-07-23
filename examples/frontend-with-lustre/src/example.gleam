import formal/form.{type Form}
import gleam/list
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

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

type Model {
  FormPage(form: Form(Signup))
  SuccessPage(data: Signup)
}

type Msg {
  /// This message is emitted by the `on_submit` function when the form is
  /// submitted. It contains the result from running the form, which is either
  /// successfully decoded data, or the form with new errors.
  UserSubmittedSignupForm(result: Result(Signup, Form(Signup)))
  UserClickedSignupLink
}

/// The initial state of the application is to be on the form page with a fresh
/// signup form.
fn init(_args: anything) -> Model {
  FormPage(form: signup_form())
}

fn update(_model: Model, msg: Msg) -> Model {
  case msg {
    // The form was valid! We can transition to the success page.
    UserSubmittedSignupForm(result: Ok(signup)) -> SuccessPage(data: signup)

    // The form was invalid. Stay on the form page and use the new form state
    // so the new errors are presented to the user by the view function.
    UserSubmittedSignupForm(result: Error(form)) -> FormPage(form:)

    // The user wants to navigate back to the form, so set the model to the
    // form page with a new empty form state.
    UserClickedSignupLink -> FormPage(form: signup_form())
  }
}

fn view(model: Model) -> Element(Msg) {
  let css = "https://cdn.jsdelivr.net/npm/@picocss/pico@2.1.1/css/pico.min.css"

  html.div([attribute.class("container")], [
    html.link([
      attribute.href(css),
      attribute.rel("stylesheet"),
    ]),

    // Conditionally render the right page based on which page we are on.
    case model {
      FormPage(form:) -> signup_page_view(form)
      SuccessPage(data:) -> success_page_view(data)
    },
  ])
}

// Show a success page to the user
fn success_page_view(data: Signup) -> Element(Msg) {
  html.div([], [
    html.h1([], [element.text("Welcome " <> data.email)]),
    html.p([], [element.text("You have successfully signed up!")]),
    html.p([], [
      html.a([event.on_click(UserClickedSignupLink)], [
        element.text("Back"),
      ]),
    ]),
  ])
}

/// Render a HTML form. Some helper functions have been created to help
/// with rendering the label, input, and any errors.
/// In a real application you'd likely want more sophisticated form field
/// functions.
fn signup_page_view(form: Form(Signup)) -> Element(Msg) {
  // This event handler is used when the form is submitted. It decodes the fields
  // from the HTML using the `Form`, and dispatches the result back to the
  // application with the `FormSubmitted` message.
  let submitted = fn(fields) {
    form |> form.add_values(fields) |> form.run |> UserSubmittedSignupForm
  }

  html.form([attribute.method("POST"), event.on_submit(submitted)], [
    field_input(form, "email", kind: "text", label: "Email"),
    field_input(form, "password", kind: "password", label: "Password"),
    field_input(form, "confirm", kind: "password", label: "Confirmation"),
    field_input(form, "terms", kind: "checkbox", label: "Accept terms"),
    html.div([], [html.input([attribute.type_("submit")])]),
  ])
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

// Lastly, start the application!
pub fn main() -> Nil {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
