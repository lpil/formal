import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string

// TODO: custom parser
// TODO: mapping

/// A form! Created from a `Schema` with the `new` function.
///
/// Supply values to a form with the `add_*` functions and then pass it to the
/// `run` function to get either the resulting value or any errors.
///
/// Use the `language` function to supply a new translation function to change
/// the language of the error messages returned by the `error_text` function.
/// The default language is `en_gb` English.
///
pub opaque type Form(model) {
  Form(
    translator: fn(FieldError) -> String,
    values: List(#(String, String)),
    errors: List(#(String, List(FieldError))),
    run: RunFunction(model),
  )
}

type RunFunction(model) =
  fn(List(#(String, String)), List(#(String, List(FieldError)))) ->
    #(model, List(#(String, List(FieldError))))

/// A description of how to decode from typed value from form data. This can be
/// used to create a new form object using the `new` function.
///
pub opaque type Schema(model) {
  Schema(run: RunFunction(model))
}

pub type FieldError {
  MustBePresent
  MustBeInt
  // TODO: parser
  MustBeFloat
  MustBeEmail
  // TODO: parser
  MustBePhoneNumber
  // TODO: parser
  MustBeUrl
  // TODO: parser
  MustBeDate
  // TODO: parser
  MustBeTime
  // TODO: parser
  MustBeDateTime
  // TODO: parser
  MustBeColour
  // TODO: parser
  MustBeStringLengthMoreThan(limit: Int)
  // TODO: parser
  MustBeStringLengthLessThan(limit: Int)
  MustBeIntMoreThan(limit: Int)
  MustBeIntLessThan(limit: Int)
  // TODO: parser
  MustBeFloatMoreThan(limit: Float)
  // TODO: parser
  MustBeFloatLessThan(limit: Float)
  // TODO: parser
  MustMatch
  // TODO: parser
  MustBeAccepted
  // TODO: parser
  CustomError(message: String)
}

// TODO: document
// TODO: test
pub opaque type Parser(input, value) {
  Parser(run: fn(input) -> #(value, List(FieldError)))
}

/// Create a new form from a schema.
///
/// Add values to the form with the `add_*` functions and use `run` to get
/// either the final value or some errors from the form and values.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use name <- form.field("name", {
///     form.parse_string
///     |> form.check_not_empty
///   })
///   use name <- form.field("age", form.parse_int)
///   form.success(Person(name:, age:))
/// }
/// let form = form.new(schema)
/// ```
///
pub fn new(schema: Schema(model)) -> Form(model) {
  Form(translator: en_gb, errors: [], values: [], run: schema.run)
}

// TODO: test
/// Supply a transation function that will be used when converting any
/// `FieldError`s to text that can be presented by the user.
///
/// Build-in languages:
///
/// - `en_gb`
/// - `en_us`
///
/// These functions are named using the IETF language tag for the langauge they
/// translate to.
///
/// If no language is supplied then `en_gb` is used by default.
///
pub fn language(
  form: Form(model),
  translator: fn(FieldError) -> String,
) -> Form(model) {
  Form(..form, translator:)
}

/// Get all the errors within a form.
///
/// If `run` or `add_error` have not been called then there will be no errors.
///
pub fn all_errors(form: Form(model)) -> List(#(String, List(FieldError))) {
  form.errors
}

/// Get all the values within a form.
///
pub fn all_values(form: Form(model)) -> List(#(String, String)) {
  form.values
}

// TODO: document
// TODO: test
pub fn get_values(form: Form(model), name: String) -> List(String) {
  form.values |> list.key_filter(name)
}

// TODO: document
// TODO: test
pub fn run(form: Form(model)) -> Result(model, Form(model)) {
  let #(value, errors) = form.run(form.values, [])
  case errors {
    [] -> Ok(value)
    _ -> Error(Form(..form, errors:))
  }
}

// TODO: document
// TODO: test
pub fn field(
  name: String,
  parser: Parser(String, value),
  continuation: fn(value) -> Schema(model),
) -> Schema(model) {
  run_field(name, parser, continuation, fn(values) {
    list.key_find(values, name) |> result.unwrap("")
  })
}

// TODO: document
// TODO: test
pub fn multifield(
  name: String,
  parser: Parser(List(String), value),
  continuation: fn(value) -> Schema(model),
) -> Schema(model) {
  run_field(name, parser, continuation, fn(values) {
    list.key_filter(values, name)
  })
}

fn run_field(
  name: String,
  parser: Parser(input, value),
  continuation: fn(value) -> Schema(model),
  getter: fn(List(#(String, String))) -> input,
) -> Schema(model) {
  Schema(fn(values, errors) {
    let input = getter(values)
    let #(value, new_errors) = parser.run(input)
    let errors = case new_errors {
      [] -> errors
      _ -> [#(name, new_errors), ..errors]
    }
    continuation(value).run(values, errors)
  })
}

// TODO: document
// TODO: test
// TODO: implement
pub fn success(value: model) -> Schema(model) {
  Schema(fn(_, errors) { #(value, errors) })
}

// TODO: document
// TODO: test
pub fn parse_list(
  parser: Parser(input, output),
) -> Parser(List(input), List(output)) {
  Parser(fn(inputs) {
    let #(values, errors) =
      list.fold(inputs, #([], []), fn(acc, value) {
        let #(value, errors) = parser.run(value)
        #([value, ..acc.0], [errors, ..acc.1])
      })
    let values = list.reverse(values)
    let errors = list.reverse(errors) |> list.flatten |> list.unique
    #(values, errors)
  })
}

// TODO: document
// TODO: test
// TODO: implement
pub fn add_values(form: Form(a), values: List(#(String, String))) -> Form(a) {
  Form(..form, values: list.append(values, form.values))
}

// TODO: document
// TODO: test
pub fn parse_optional(
  parser: Parser(String, output),
) -> Parser(String, option.Option(output)) {
  Parser(fn(input) {
    case input {
      "" -> #(option.None, [])
      _ -> {
        let #(value, errors) = parser.run(input)
        #(option.Some(value), errors)
      }
    }
  })
}

// TODO: document
// TODO: test
// TODO: implement
pub const parse_string: Parser(String, String) = Parser(string_parser)

fn string_parser(input: String) -> #(String, List(FieldError)) {
  #(input, [])
}

// TODO: document
// TODO: test
pub const parse_int: Parser(String, Int) = Parser(int_parser)

fn int_parser(input: String) -> #(Int, List(FieldError)) {
  case int.parse(input) {
    Ok(x) -> #(x, [])
    _ -> #(0, [MustBeInt])
  }
}

// TODO: document
// TODO: test
pub const parse_email: Parser(String, String) = Parser(email_parser)

fn email_parser(input: String) -> #(String, List(FieldError)) {
  case string.contains(input, "@") {
    True -> #(input, [])
    _ -> #("", [MustBeEmail])
  }
}

// TODO: document
// TODO: test
// TODO: implement
pub fn check(
  parser: Parser(a, b),
  checker: fn(b) -> Result(b, String),
) -> Parser(a, b) {
  check_map(parser, CustomError, checker)
}

fn check_map(
  parser: Parser(a, b),
  map: fn(error) -> FieldError,
  checker: fn(b) -> Result(b, error),
) -> Parser(a, b) {
  Parser(fn(a) {
    let #(value, errors) = parser.run(a)
    let errors = case checker(value) {
      Error(error) -> [map(error), ..errors]
      Ok(_) -> errors
    }
    #(value, errors)
  })
}

// TODO: document
// TODO: test
// TODO: implement
pub fn check_not_empty(parser: Parser(a, String)) -> Parser(a, String) {
  check_map(parser, fn(x) { x }, fn(x) {
    case x {
      "" -> Error(MustBePresent)
      _ -> Ok(x)
    }
  })
}

// TODO: document
// TODO: test
// TODO: implement
pub fn check_int_less_than(parser: Parser(a, Int), limit: Int) -> Parser(a, Int) {
  check_map(parser, fn(x) { x }, fn(x) {
    case x < limit {
      True -> Ok(x)
      _ -> Error(MustBeIntLessThan(limit))
    }
  })
}

// TODO: document
// TODO: test
pub fn check_int_more_than(parser: Parser(a, Int), limit: Int) -> Parser(a, Int) {
  check_map(parser, fn(x) { x }, fn(x) {
    case x > limit {
      True -> Ok(x)
      _ -> Error(MustBeIntMoreThan(limit))
    }
  })
}

// TODO: document
// TODO: test
/// Translates `FieldError`s into strings suitable for showing to the user.
///
/// ## Examples
///
/// ```gleam
/// assert en_us(MustBeColour) == "must be a hex colour code"
/// ```
///
pub fn en_gb(error: FieldError) -> String {
  case error {
    MustBeAccepted -> "must be accepted"
    MustBeColour -> "must be a hex colour code"
    MustBeDate -> "must be a date"
    MustBeDateTime -> "must be a date and time"
    MustBeEmail -> "must be an email"
    MustBeFloat -> "must be a number"
    MustBeFloatLessThan(limit:) ->
      "must be less than " <> float.to_string(limit)
    MustBeFloatMoreThan(limit:) ->
      "must be more than " <> float.to_string(limit)
    MustBeInt -> "must be a whole number"
    MustBeIntLessThan(limit:) -> "must be less than " <> int.to_string(limit)
    MustBeIntMoreThan(limit:) -> "must be more than " <> int.to_string(limit)
    MustBePhoneNumber -> "must be a phone number"
    MustBePresent -> "must not be blank"
    MustBeStringLengthLessThan(limit:) ->
      "must be less than " <> int.to_string(limit) <> " characters"
    MustBeStringLengthMoreThan(limit:) ->
      "must be more than " <> int.to_string(limit) <> " characters"
    MustBeTime -> "must be a time"
    MustBeUrl -> "must be a URL"
    MustMatch -> "must match"
    CustomError(message:) -> message
  }
}

// TODO: test
/// Translates `FieldError`s into strings suitable for showing to the user.
///
/// The same as `en_gb`, but with Americanised spelling of the word "color".
///
/// ## Examples
///
/// ```gleam
/// assert en_us(MustBeColour) == "must be a hex color code"
/// ```
///
pub fn en_us(error: FieldError) -> String {
  case error {
    MustBeColour -> "must be a hex color code"
    _ -> en_gb(error)
  }
}

// TODO: document
// TODO: test
pub fn add_string(
  form: Form(model),
  field: String,
  value: String,
) -> Form(model) {
  Form(..form, values: [#(field, value), ..form.values])
}

// TODO: document
pub fn add_int(form: Form(model), field: String, value: Int) -> Form(model) {
  Form(..form, values: [#(field, int.to_string(value)), ..form.values])
}

// TODO: document
// TODO: test
pub fn error_text(form: Form(model), name: String) -> List(String) {
  form.errors
  |> list.key_filter(name)
  |> list.flat_map(list.map(_, form.translator))
}

/// Get all the form.
///
/// If the `run` function or the `add_error` function have not been called then
/// the form is clean and won't have any errors yet.
///
pub fn errors(form: Form(model), name: String) -> List(FieldError) {
  form.errors
  |> list.key_filter(name)
  |> list.flatten
}

// TODO: document
// TODO: test
pub fn add_error(form: Form(model), name: String, error: String) -> Form(model) {
  Form(..form, errors: [#(name, [CustomError(error)]), ..form.errors])
}
