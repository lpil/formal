import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/uri

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
  MustBeFloat
  MustBeEmail
  MustBePhoneNumber
  MustBeUrl
  MustBeDate
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
pub opaque type Parser(value) {
  Parser(run: fn(List(String)) -> #(value, List(FieldError)))
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
  parser: Parser(value),
  continuation: fn(value) -> Schema(model),
) -> Schema(model) {
  Schema(fn(values, errors) {
    let input = list.key_filter(values, name)
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
pub fn parse_list(parser: Parser(output)) -> Parser(List(output)) {
  Parser(fn(inputs) {
    let #(values, errors) =
      list.fold(inputs, #([], []), fn(acc, value) {
        let #(value, errors) = parser.run([value])
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
pub fn parse_optional(parser: Parser(output)) -> Parser(option.Option(output)) {
  Parser(fn(inputs) {
    case inputs {
      [] | [""] -> #(option.None, [])
      _ -> {
        let #(value, errors) = parser.run(inputs)
        #(option.Some(value), errors)
      }
    }
  })
}

/// Parse a string value. This parser can never fail!
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use name <- form.field("name", {
///     form.parse_string
///     |> form.check_not_empty
///   })
///   form.success(Person(name:))
/// }
/// ```
///
pub const parse_string: Parser(String) = Parser(string_parser)

fn string_parser(inputs: List(String)) -> #(String, List(FieldError)) {
  case inputs {
    [input, ..] -> #(input, [])
    [] -> #("", [])
  }
}

/// A parser for a whole number.
///
/// Returns a `MustBeInt` error if the input cannot be parsed as a valid int.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use age <- form.field("age", {
///     form.parse_int
///     |> form.check_int_more_than(0)
///   })
///   form.success(Person(age:))
/// }
/// ```
///
pub const parse_int: Parser(Int) = Parser(int_parser)

fn int_parser(inputs: List(String)) -> #(Int, List(FieldError)) {
  use input <- value_parser(inputs, 0, MustBeInt)
  int.parse(input)
}

fn value_parser(
  inputs: List(String),
  zero: t,
  error: FieldError,
  next: fn(String) -> Result(t, e),
) -> #(t, List(FieldError)) {
  case inputs {
    [input, ..] ->
      case next(input) {
        Ok(t) -> #(t, [])
        Error(_) -> #(zero, [error])
      }
    _ -> #(zero, [error])
  }
}

/// A parser for floating point numbers.
///
/// Returns a `MustBeFloat` error if the input cannot be parsed as a float.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use price <- form.field("price", {
///     form.parse_float
///     |> form.check_float_more_than(0.0)
///   })
///   form.success(Product(price:))
/// }
/// ```
///
pub const parse_float: Parser(Float) = Parser(float_parser)

fn float_parser(inputs: List(String)) -> #(Float, List(FieldError)) {
  use input <- value_parser(inputs, 0.0, MustBeFloat)
  float.parse(input)
}

/// A parser that validates email addresses.
///
/// Performs basic email validation by checking for the presence of an "@" symbol.
/// Returns a `MustBeEmail` error if the input is not a valid email format.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use email <- form.field("email", form.parse_email)
///   form.success(Person(email:))
/// }
/// ```
///
pub const parse_email: Parser(String) = Parser(email_parser)

fn email_parser(inputs: List(String)) -> #(String, List(FieldError)) {
  use input <- value_parser(inputs, "", MustBeEmail)
  case string.contains(input, "@") {
    True -> Ok(input)
    False -> Error(Nil)
  }
}

/// A parser for phone numbers.
///
/// Phone numbers are checked with these rules:
/// - Must be between 7 and 15 characters after removing formatting
/// - Must contain only digits after removing formatting characters
/// - `+` may optionally be the first character.
/// - `-`, ` `, `(`, and `)` are permitted, but are removed.
///
/// Returns a `MustBePhoneNumber` error if the input doesn't satisfy these
/// rules.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use phone <- form.field("phone", form.parse_phone_number)
///   form.success(Person(phone:))
/// }
/// ```
///
pub const parse_phone_number: Parser(String) = Parser(phone_number_parser)

fn phone_number_parser(inputs: List(String)) -> #(String, List(FieldError)) {
  use input <- value_parser(inputs, "", MustBePhoneNumber)
  phone_number_loop(input, "", 0)
}

fn phone_number_loop(
  input: String,
  tel: String,
  size: Int,
) -> Result(String, Nil) {
  case input {
    _ if size > 15 -> Error(Nil)
    "" if size > 7 -> Ok(tel)
    "" -> Error(Nil)

    "+" <> input if tel == "" -> phone_number_loop(input, tel, size)
    "-" <> input | "(" <> input | ")" <> input | " " <> input if tel != "" ->
      phone_number_loop(input, tel, size)

    "0" as d <> input
    | "1" as d <> input
    | "2" as d <> input
    | "3" as d <> input
    | "4" as d <> input
    | "5" as d <> input
    | "6" as d <> input
    | "7" as d <> input
    | "8" as d <> input
    | "9" as d <> input -> phone_number_loop(input, tel <> d, size + 1)

    _ -> Error(Nil)
  }
}

/// A parser for URLs.
///
/// Uses the `gleam/uri` module to parse and validate URLs. Returns a
/// `MustBeUrl` error if the input cannot be parsed as a valid URI.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use website <- form.field("website", form.parse_url)
///   form.success(Company(website:))
/// }
/// ```
///
pub const parse_url: Parser(uri.Uri) = Parser(url_parser)

fn url_parser(inputs: List(String)) -> #(uri.Uri, List(FieldError)) {
  use input <- value_parser(inputs, uri.empty, MustBeUrl)
  uri.parse(input)
}

/// A parser for calendar dates.
///
/// Parses dates in YYYY-MM-DD format and returns a `calendar.Date` value.
/// Returns a `MustBeDate` error if the input cannot be parsed as a valid date.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use birth_date <- form.field("birth_date", form.parse_date)
///   form.success(Person(birth_date:))
/// }
/// ```
///
pub const parse_date: Parser(calendar.Date) = Parser(date_parser)

fn date_parser(inputs: List(String)) -> #(calendar.Date, List(FieldError)) {
  let zero = calendar.Date(1970, calendar.January, 1)
  use input <- value_parser(inputs, zero, MustBeDate)
  case string.split(input, "-") {
    [year_str, month_str, day_str] -> {
      use year <- result.try(int.parse(year_str))
      use month <- result.try(int.parse(month_str))
      use day <- result.try(int.parse(day_str))
      use month <- result.try(calendar.month_from_int(month))
      let date = calendar.Date(year, month, day)
      case calendar.is_valid_date(date) {
        True -> Ok(date)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

/// A parser for time values.
///
/// Parses times in HH:MM:SS or HH:MM format and returns a `calendar.TimeOfDay`
/// value.
/// Returns a `MustBeTime` error if the input cannot be parsed as a valid time.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use start_time <- form.field("start_time", form.parse_time)
///   form.success(Event(start_time:))
/// }
/// ```
///
pub const parse_time: Parser(calendar.TimeOfDay) = Parser(time_parser)

fn time_parser(inputs: List(String)) -> #(calendar.TimeOfDay, List(FieldError)) {
  use input <- value_parser(inputs, calendar.TimeOfDay(0, 0, 0, 0), MustBeTime)
  case string.split(input, ":") {
    [hour_str, minute_str, second_str] -> {
      parse_time_parts(hour_str, minute_str, second_str)
    }
    [hour_str, minute_str] -> {
      parse_time_parts(hour_str, minute_str, "0")
    }
    _ -> Error(Nil)
  }
}

fn parse_time_parts(
  hour_str: String,
  minute_str: String,
  second_str: String,
) -> Result(calendar.TimeOfDay, Nil) {
  use hour <- result.try(int.parse(hour_str))
  use minute <- result.try(int.parse(minute_str))
  use second <- result.try(int.parse(second_str))
  let time = calendar.TimeOfDay(hour, minute, second, 0)
  case calendar.is_valid_time_of_day(time) {
    True -> Ok(time)
    False -> Error(Nil)
  }
}

// TODO: document
// TODO: test
// TODO: implement
pub fn check(
  parser: Parser(b),
  checker: fn(b) -> Result(b, String),
) -> Parser(b) {
  check_map(parser, CustomError, checker)
}

fn check_map(
  parser: Parser(b),
  map: fn(error) -> FieldError,
  checker: fn(b) -> Result(b, error),
) -> Parser(b) {
  Parser(fn(inputs) {
    let #(value, errors) = parser.run(inputs)
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
pub fn check_not_empty(parser: Parser(String)) -> Parser(String) {
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
pub fn check_int_less_than(parser: Parser(Int), limit: Int) -> Parser(Int) {
  check_map(parser, fn(x) { x }, fn(x) {
    case x < limit {
      True -> Ok(x)
      _ -> Error(MustBeIntLessThan(limit))
    }
  })
}

// TODO: document
// TODO: test
pub fn check_int_more_than(parser: Parser(Int), limit: Int) -> Parser(Int) {
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
pub fn add_error(
  form: Form(model),
  name: String,
  error: FieldError,
) -> Form(model) {
  Form(..form, errors: [#(name, [error]), ..form.errors])
}
