import gleam/bit_array
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/uri

/// A form! Created from a `Schema` with the `new` function.
///
/// Supply values to a form with the `add_*` functions and then pass it to the
/// `run` function to get either the resulting value or any errors.
///
/// Use the `language` function to supply a new translation function to change
/// the language of the error messages returned by the `field_error_text` function.
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
  MustBeDateTime
  MustBeColour
  MustBeStringLengthMoreThan(limit: Int)
  MustBeStringLengthLessThan(limit: Int)
  MustBeIntMoreThan(limit: Int)
  MustBeIntLessThan(limit: Int)
  MustBeFloatMoreThan(limit: Float)
  MustBeFloatLessThan(limit: Float)
  MustBeAccepted
  /// For confirmation of passwords, etc. Must match the first field.
  MustConfirm
  /// For values that must be unique. e.g. user email addresses.
  MustBeUnique
  CustomError(message: String)
}

/// A parser extracts a value from from values, converting it to a desired type
/// and optionally validating the value. Parsers are used with the `field`
/// function.
///
/// See the `parse_*` and `check_*` functions for more information.
///
/// Functions that start with `parse_*` are _short-circuiting_, so any parser
/// functions that come afterwrads will not be run. For example, given this
/// code:
///
/// ```gleam
/// form.parse_int |> form.check_int_more_than(0)
/// ```
///
/// If the input is not an int then `parse_int` will fail, causing
/// `check_int_more_than` not to run, so the errors will be `[MustBeInt]`.
///
pub opaque type Parser(value) {
  Parser(
    run: fn(List(String), CheckingStatus) ->
      #(value, CheckingStatus, List(FieldError)),
  )
}

type CheckingStatus {
  Check
  DontCheck
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

/// Supply a transation function that will be used when converting any
/// `FieldError`s to text that can be presented to the user.
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

/// Get all the values for a given form field.
///
/// ## Examples
///
/// ```gleam
/// let form = form
///   |> form.add_int("one", 100)
///   |> form.add_string("one", "Hello")
///   |> form.add_string("two", "Hi!")
/// assert form.field_values(form, "one") == ["Hello", "100"]
/// ```
///
pub fn field_values(form: Form(model), name: String) -> List(String) {
  form.values |> list.key_filter(name)
}

// TODO: test
/// Get the first values for a given form field.
///
/// ## Examples
///
/// ```gleam
/// let form = form |> form.add_int("one", 100)
/// assert form.field_value(form, "one") == "100"
/// assert form.field_value(form, "two") == ""
/// ```
///
pub fn field_value(form: Form(model), name: String) -> String {
  form.values |> list.key_find(name) |> result.unwrap("")
}

/// Run a form, returning either the successfully parsed value if there are no
/// errors, or a new instance of the form with the errors added to the fields.
///
pub fn run(form: Form(model)) -> Result(model, Form(model)) {
  let #(value, errors) = form.run(form.values, [])
  case errors {
    [] -> Ok(value)
    _ -> Error(Form(..form, errors:))
  }
}

/// Add a new parser to the form for a given form field name.
///
pub fn field(
  name: String,
  parser: Parser(value),
  continuation: fn(value) -> Schema(model),
) -> Schema(model) {
  Schema(fn(values, errors) {
    let input = list.key_filter(values, name)
    let #(value, _status, new_errors) = parser.run(input, Check)
    let errors = case new_errors {
      [] -> errors
      _ -> [#(name, new_errors), ..errors]
    }
    continuation(value).run(values, errors)
  })
}

/// Finalise a parser, having successfully parsed a value.
///
pub fn success(value: model) -> Schema(model) {
  Schema(fn(_, errors) { #(value, errors) })
}

/// A parser that applies another parser to each input value in a list.
///
/// Takes a parser for a single value and returns a parser that can handle
/// multiple values of the same type. This is useful for form fields that
/// can have multiple values, such as checkboxes, multi-selects, or just
/// repeated inputs of other types.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use tags <- form.field("tag", form.parse_list(form.parse_string))
///   form.success(Article(tags:))
/// }
/// ```
///
/// This would parse multiple "tag" fields into a list of strings.
///
pub fn parse_list(parser: Parser(output)) -> Parser(List(output)) {
  Parser(fn(inputs, check) {
    let #(values, status, errors) =
      list.fold(inputs, #([], Check, []), fn(acc, value) {
        let #(value, status, errors) = parser.run([value], check)
        #([value, ..acc.0], status, [errors, ..acc.2])
      })
    let values = list.reverse(values)
    let errors = list.reverse(errors) |> list.flatten |> list.unique
    #(values, status, errors)
  })
}

/// Add multiple values to a form. This function is useful for adding values
/// from a HTTP request form body sent to your server, or from a HTML form
/// element in your browser-based application.
///
/// ## Example
///
/// ```gleam
/// use formdata <- wisp.require_form(request)
/// let form <- new_user_form() |> form.add_values(formdata.values)
/// ```
///
pub fn add_values(form: Form(a), values: List(#(String, String))) -> Form(a) {
  Form(..form, values: list.append(values, form.values))
}

/// Replace any existing values of a form with new values. This function is
/// useful for adding values from a HTTP request form body sent to your server,
/// or from a HTML form element in your browser-based application.
///
/// ## Example
///
/// ```gleam
/// use formdata <- wisp.require_form(request)
/// let form <- new_user_form() |> form.set_values(formdata.values)
/// ```
///
pub fn set_values(form: Form(a), values: List(#(String, String))) -> Form(a) {
  Form(..form, values:)
}

/// A parser that applies another parser if there is a non-empty-string input
/// value for the field.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use age <- form.field("tag", form.parse_optional(form.parse_int))
///   form.success(Person(age:))
/// }
/// ```
///
/// This would parse an int if the form field has text in it, returning `None`
/// otherwise.
///
pub fn parse_optional(parser: Parser(output)) -> Parser(option.Option(output)) {
  Parser(fn(inputs, check) {
    case inputs {
      [] | [""] -> #(option.None, check, [])
      _ -> {
        let #(value, status, errors) = parser.run(inputs, check)
        #(option.Some(value), status, errors)
      }
    }
  })
}

/// Parse a bool value from a checkbox type input.
///
/// No value `False`, while any value (including empty string) counts as
/// `True`. A checked checkbox input with no explicitly set value has the value
/// `"on"`, which is True. Unchecked checkbox inputs send no value when the
/// form is submitted, they are absent from the sent payload.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use agreed <- form.field("terms-and-conditions", {
///     form.parse_checkbox
///     |> form.check_accepted
///   })
///   form.success(Signup(agreed:))
/// }
/// ```
///
pub const parse_checkbox: Parser(Bool) = Parser(checkbox_parser)

fn checkbox_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(Bool, CheckingStatus, List(FieldError)) {
  case inputs {
    [] -> #(False, status, [])
    _ -> #(True, status, [])
  }
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

fn string_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(String, CheckingStatus, List(FieldError)) {
  case inputs {
    [input, ..] -> #(input, status, [])
    [] -> #("", status, [])
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

fn int_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(Int, CheckingStatus, List(FieldError)) {
  use input <- value_parser(inputs, 0, status, MustBeInt)
  int.parse(input)
}

fn value_parser(
  inputs: List(String),
  zero: t,
  status: CheckingStatus,
  error: FieldError,
  next: fn(String) -> Result(t, e),
) -> #(t, CheckingStatus, List(FieldError)) {
  case inputs {
    [input, ..] ->
      case next(input) {
        Ok(t) -> #(t, status, [])
        Error(_) -> #(zero, DontCheck, [error])
      }
    _ -> #(zero, DontCheck, [error])
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

fn float_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(Float, CheckingStatus, List(FieldError)) {
  use input <- value_parser(inputs, 0.0, status, MustBeFloat)
  case float.parse(input) {
    Ok(result) -> Ok(result)
    Error(_) ->
      int.parse(input)
      |> result.map(int.to_float)
  }
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

fn email_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(String, CheckingStatus, List(FieldError)) {
  use input <- value_parser(inputs, "", status, MustBeEmail)
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

fn phone_number_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(String, CheckingStatus, List(FieldError)) {
  use input <- value_parser(inputs, "", status, MustBePhoneNumber)
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

fn url_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(uri.Uri, CheckingStatus, List(FieldError)) {
  use input <- value_parser(inputs, uri.empty, status, MustBeUrl)
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

fn date_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(calendar.Date, CheckingStatus, List(FieldError)) {
  let zero = calendar.Date(1970, calendar.January, 1)
  use input <- value_parser(inputs, zero, status, MustBeDate)
  case string.split(input, "-") {
    [year, month, day] -> {
      use year <- result.try(int.parse(year))
      use month <- result.try(int.parse(month))
      use day <- result.try(int.parse(day))
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

fn time_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(calendar.TimeOfDay, CheckingStatus, List(FieldError)) {
  use input <- value_parser(
    inputs,
    calendar.TimeOfDay(0, 0, 0, 0),
    status,
    MustBeTime,
  )
  case string.split(input, ":") {
    [hour, minute, second] -> {
      parse_time_parts(hour, minute, second)
    }
    [hour, minute] -> {
      parse_time_parts(hour, minute, "0")
    }
    _ -> Error(Nil)
  }
}

/// A parser for datetime values.
///
/// Parses datetime strings in HTML datetime-local format (e.g.
/// "2023-12-25T14:30" or "2023-12-25T14:30:00")
/// and returns a tuple of `(calendar.Date, calendar.TimeOfDay)`.
///
/// Returns a `MustBeDateTime` error if the input cannot be parsed as a valid
/// datetime.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use created_at <- form.field("created_at", form.parse_date_time)
///   form.success(Event(created_at:))
/// }
/// ```
///
pub const parse_date_time: Parser(#(calendar.Date, calendar.TimeOfDay)) = Parser(
  date_time_parser,
)

fn date_time_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(#(calendar.Date, calendar.TimeOfDay), CheckingStatus, List(FieldError)) {
  let zero = #(
    calendar.Date(1970, calendar.January, 1),
    calendar.TimeOfDay(0, 0, 0, 0),
  )
  use input <- value_parser(inputs, zero, status, MustBeDateTime)
  case string.split_once(input, "T") {
    Ok(#(date_part, time_part)) -> {
      case string.split(date_part, "-"), string.split(time_part, ":") {
        [year, month, day], [hour, minute] -> {
          parse_date_time_parts(year, month, day, hour, minute, "0")
        }
        [year, month, day], [hour, minute, second] -> {
          parse_date_time_parts(year, month, day, hour, minute, second)
        }
        _, _ -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn parse_date_time_parts(
  year: String,
  month: String,
  day: String,
  hour: String,
  minute: String,
  second: String,
) -> Result(#(calendar.Date, calendar.TimeOfDay), Nil) {
  use year <- result.try(int.parse(year))
  use month <- result.try(int.parse(month))
  use day <- result.try(int.parse(day))
  use hour <- result.try(int.parse(hour))
  use minute <- result.try(int.parse(minute))
  use second <- result.try(int.parse(second))
  use month <- result.try(calendar.month_from_int(month))
  let date = calendar.Date(year, month, day)
  let time = calendar.TimeOfDay(hour, minute, second, 0)
  case calendar.is_valid_date(date) && calendar.is_valid_time_of_day(time) {
    True -> Ok(#(date, time))
    False -> Error(Nil)
  }
}

fn parse_time_parts(
  hour: String,
  minute: String,
  second: String,
) -> Result(calendar.TimeOfDay, Nil) {
  use hour <- result.try(int.parse(hour))
  use minute <- result.try(int.parse(minute))
  use second <- result.try(int.parse(second))
  let time = calendar.TimeOfDay(hour, minute, second, 0)
  case calendar.is_valid_time_of_day(time) {
    True -> Ok(time)
    False -> Error(Nil)
  }
}

/// A parser for colour values.
///
/// Parses color strings in HTML hex format (e.g., "#FF0000", "#00ff00")
/// and returns the hex color string.
///
/// Returns a `MustBeColour` error if the input is not a valid hex color.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use background_color <- form.field("background_color", form.parse_colour)
///   form.success(Theme(background_color:))
/// }
/// ```
///
pub const parse_colour: Parser(String) = Parser(colour_parser)

fn colour_parser(
  inputs: List(String),
  status: CheckingStatus,
) -> #(String, CheckingStatus, List(FieldError)) {
  use input <- value_parser(inputs, "", status, MustBeColour)
  use <- bool.guard(string.byte_size(input) != 7, Error(Nil))
  case input {
    "#" <> hex -> {
      case bit_array.base16_decode(hex) {
        Ok(_) -> Ok(input)
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

/// Add a custom check to the parser.
///
/// ## Examples
///
/// ```gleam
/// let must_not_be_rude = fn(text) {
///   case contains_swear_word(text) {
///     True -> Error("must not be rude")
///     False -> Ok(text)
///   }
/// }
/// let schema = {
///   use name <- form.field("name", {
///     form.parse_string
///     |> form.check(must_not_be_rude)
///   })
///   form.success(Profile(name:))
/// }
/// ```
///
/// ## Internationalisation
///
/// If your application supports multiple languages you will need to ensure the
/// error string returned by your checker function is already in the desired
/// language.
///
pub fn check(
  parser: Parser(b),
  checker: fn(b) -> Result(b, String),
) -> Parser(b) {
  add_check(parser, fn(a) {
    case checker(a) {
      Ok(a) -> Ok(a)
      Error(e) -> Error(CustomError(e))
    }
  })
}

/// Create a custom parser for any type.
///
/// If the parser function fails it must return two values:
/// - A default "zero" value of the expected type. This will be used to run the
///   remaining parser code, and then will be discarded.
/// - An error message string to present to the user.
///
/// ## Examples
///
/// ```gleam
/// form.parse(fn(input) {
///   case input {
///     ["Squirtle", ..] -> Ok(Squirtle)
///     ["Bulbasaur", ..] -> Ok(Bulbasaur)
///     ["Charmander", ..] -> Ok(Charmander)
///     _ -> Error(#(Squirtle, "must be a starter Pokémon"))
///   }
/// })
/// ```
///
/// ## Internationalisation
///
/// If your application supports multiple languages you will need to ensure the
/// error string returned by your parser function is already in the desired
/// language.
///
pub fn parse(parser: fn(List(String)) -> Result(t, #(t, String))) -> Parser(t) {
  Parser(fn(input, status) {
    case parser(input) {
      Ok(t) -> #(t, status, [])
      Error(#(t, error)) -> #(t, DontCheck, [CustomError(error)])
    }
  })
}

fn add_check(
  parser: Parser(b),
  checker: fn(b) -> Result(b, FieldError),
) -> Parser(b) {
  Parser(fn(inputs, status) {
    let #(value, status, errors) = parser.run(inputs, status)
    let errors = case status {
      Check ->
        case checker(value) {
          Error(error) -> [error, ..errors]
          Ok(_) -> errors
        }
      DontCheck -> errors
    }
    #(value, status, errors)
  })
}

/// Convert the parsed value into another, similar to `list.map` or
/// `result.map`.
///
pub fn map(parser: Parser(t1), mapper: fn(t1) -> t2) -> Parser(t2) {
  Parser(fn(input, status) {
    let #(t1, status, errors) = parser.run(input, status)
    #(mapper(t1), status, errors)
  })
}

/// Ensure that the string value is not an empty string.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use tags <- form.field("tag", {
///     form.parse_string
///     |> form.check_not_empty
///   })
///   form.success(Article(tags:))
/// }
/// ```
///
pub fn check_not_empty(parser: Parser(String)) -> Parser(String) {
  add_check(parser, fn(x) {
    case x {
      "" -> Error(MustBePresent)
      _ -> Ok(x)
    }
  })
}

/// Ensure that an int is less than a specified limit.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use age <- form.field("age", {
///     form.parse_int
///     |> form.check_int_less_than(150)
///   })
///   form.success(Person(age:))
/// }
/// ```
///
pub fn check_int_less_than(parser: Parser(Int), limit: Int) -> Parser(Int) {
  add_check(parser, fn(x) {
    case x < limit {
      True -> Ok(x)
      _ -> Error(MustBeIntLessThan(limit))
    }
  })
}

/// Ensure that an int is more than a specified limit.
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
pub fn check_int_more_than(parser: Parser(Int), limit: Int) -> Parser(Int) {
  add_check(parser, fn(x) {
    case x > limit {
      True -> Ok(x)
      _ -> Error(MustBeIntMoreThan(limit))
    }
  })
}

/// Ensure that a string is more than a specified length.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use password <- form.field("password", {
///     form.parse_string
///     |> form.check_string_length_more_than(8)
///   })
///   form.success(User(password:))
/// }
/// ```
///
pub fn check_string_length_more_than(
  parser: Parser(String),
  limit: Int,
) -> Parser(String) {
  add_check(parser, fn(x) {
    case string.length(x) > limit {
      True -> Ok(x)
      _ -> Error(MustBeStringLengthMoreThan(limit))
    }
  })
}

/// Ensure that a string is less than a specified length.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use username <- form.field("username", {
///     form.parse_string
///     |> form.check_string_length_less_than(20)
///   })
///   form.success(User(username:))
/// }
/// ```
///
pub fn check_string_length_less_than(
  parser: Parser(String),
  limit: Int,
) -> Parser(String) {
  add_check(parser, fn(x) {
    case string.length(x) < limit {
      True -> Ok(x)
      _ -> Error(MustBeStringLengthLessThan(limit))
    }
  })
}

/// Ensure that a float is more than a specified limit.
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
pub fn check_float_more_than(
  parser: Parser(Float),
  limit: Float,
) -> Parser(Float) {
  add_check(parser, fn(x) {
    case x >. limit {
      True -> Ok(x)
      _ -> Error(MustBeFloatMoreThan(limit))
    }
  })
}

/// Ensure that a float is less than a specified limit.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use discount <- form.field("discount", {
///     form.parse_float
///     |> form.check_float_less_than(100.0)
///   })
///   form.success(Product(discount:))
/// }
/// ```
///
pub fn check_float_less_than(
  parser: Parser(Float),
  limit: Float,
) -> Parser(Float) {
  add_check(parser, fn(x) {
    case x <. limit {
      True -> Ok(x)
      _ -> Error(MustBeFloatLessThan(limit))
    }
  })
}

/// Ensure that a bool is `True`.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use discount <- form.field("terms-and-conditions", {
///     form.parse_checkbox
///     |> form.check_accepted
///   })
///   form.success(Product(discount:))
/// }
/// ```
///
pub fn check_accepted(parser: Parser(Bool)) -> Parser(Bool) {
  add_check(parser, fn(x) {
    case x {
      True -> Ok(x)
      _ -> Error(MustBeAccepted)
    }
  })
}

/// Ensure that a field equals some other value. Useful for password
/// confirmation.
///
/// ## Example
///
/// ```gleam
/// let schema = {
///   use password <- form.field("password-confirmation", {
///     form.parse_string
///     |> form.check_string_length_more_than(8)
///   })
///   use _ <- form.field("password-confirmation", {
///     form.parse_string
///     |> form.check_confirms(password)
///   })
///   form.success(User(password:))
/// }
/// ```
///
pub fn check_confirms(parser: Parser(t), other: t) -> Parser(t) {
  add_check(parser, fn(x) {
    case x == other {
      True -> Ok(x)
      _ -> Error(MustConfirm)
    }
  })
}

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
    MustConfirm -> "doesn't match"
    MustBeUnique -> "is already in use"
    CustomError(message:) -> message
  }
}

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

/// Add a string value to the form.
///
/// You may want to use this to pre-fill a form with some already-saved
/// values for the user to edit.
///
pub fn add_string(
  form: Form(model),
  field: String,
  value: String,
) -> Form(model) {
  Form(..form, values: [#(field, value), ..form.values])
}

/// Add an int value to the form.
///
/// You may want to use this to pre-fill a form with some already-saved
/// values for the user to edit.
///
pub fn add_int(form: Form(model), field: String, value: Int) -> Form(model) {
  Form(..form, values: [#(field, int.to_string(value)), ..form.values])
}

/// Get the error messages for a field, if there are any.
///
/// The text is formatted using the translater function given with the
/// `langauge` function. The default translater is `en_gb`.
///
pub fn field_error_messages(form: Form(model), name: String) -> List(String) {
  form.errors
  |> list.key_filter(name)
  |> list.flat_map(list.map(_, form.translator))
}

/// Get all the form.
///
/// If the `run` function or the `add_error` function have not been called then
/// the form is clean and won't have any errors yet.
///
pub fn field_errors(form: Form(model), name: String) -> List(FieldError) {
  form.errors
  |> list.key_filter(name)
  |> list.flatten
}

/// Add an error to one of the fields of the form.
///
/// This function may be useful if you have some additional validation that runs
/// outside of the form schema and you want to surface the error messages to the
/// user via the form.
///
pub fn add_error(
  form: Form(model),
  name: String,
  error: FieldError,
) -> Form(model) {
  Form(..form, errors: [#(name, [error]), ..form.errors])
}
