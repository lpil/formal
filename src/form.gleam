import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type FormState {
  FormState(values: Dict(String, String), errors: Dict(String, String))
}

pub opaque type FormValidator(output) {
  InvalidForm(values: Dict(String, String), errors: Dict(String, String))
  ValidForm(values: Dict(String, String), output: output)
}

pub fn decoding(into constructor: fn(a) -> rest) -> FormValidator(fn(a) -> rest) {
  ValidForm(dict.new(), constructor)
}

pub fn with_values(
  form: FormValidator(out),
  values: List(#(String, String)),
) -> FormValidator(out) {
  let values =
    list.fold(values, get_values(form), fn(acc, pair) {
      dict.insert(acc, pair.0, pair.1)
    })

  case form {
    InvalidForm(_, errors) -> InvalidForm(values, errors)
    ValidForm(_, output) -> ValidForm(values, output)
  }
}

pub fn field(
  form: FormValidator(fn(t) -> rest),
  name: String,
  decoder: fn(String) -> Result(t, String),
) -> FormValidator(rest) {
  let result =
    form
    |> get_values
    |> dict.get(name)
    |> result.unwrap("")
    |> decoder
  case form {
    ValidForm(values, output) ->
      case result {
        Ok(next) -> ValidForm(values, output(next))
        Error(message) ->
          InvalidForm(values, dict.insert(dict.new(), name, message))
      }
    InvalidForm(values, errors) ->
      case result {
        Ok(_) -> InvalidForm(values, errors)
        Error(message) ->
          InvalidForm(values, dict.insert(errors, name, message))
      }
  }
}

pub fn finish(form: FormValidator(output)) -> Result(output, FormState) {
  case form {
    InvalidForm(values, errors) -> Error(FormState(values, errors))
    ValidForm(_, output) -> Ok(output)
  }
}

//
// Decoders
//

pub fn and(
  previous: fn(a) -> Result(b, String),
  next: fn(b) -> Result(c, String),
) -> fn(a) -> Result(c, String) {
  fn(data) {
    case previous(data) {
      Ok(value) -> next(value)
      Error(error) -> Error(error)
    }
  }
}

pub fn message(
  result: fn(a) -> Result(b, String),
  message: String,
) -> fn(a) -> Result(b, String) {
  fn(data) {
    case result(data) {
      Ok(value) -> Ok(value)
      Error(_) -> Error(message)
    }
  }
}

pub fn string(input: String) -> Result(String, String) {
  Ok(string.trim(input))
}

pub fn int(input: String) -> Result(Int, String) {
  case int.parse(input) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Must be a whole number")
  }
}

pub fn bool(input: String) -> Result(Bool, String) {
  case input {
    "on" -> Ok(True)
    _ -> Ok(False)
  }
}

pub fn must_be_non_empty(input: String) -> Result(String, String) {
  case input {
    "" -> Error("Must be given")
    _ -> Ok(input)
  }
}

pub fn must_be_an_email(input: String) -> Result(String, String) {
  case string.split(input, "@") {
    [_, _] -> Ok(input)
    _ -> Error("Must be an email")
  }
}

pub fn must_be_greater_than(minimum: Int) -> fn(Int) -> Result(Int, String) {
  fn(input) {
    case input > minimum {
      True -> Ok(input)
      False -> Error("Must be greater than " <> int.to_string(minimum))
    }
  }
}

pub fn must_be_less_than(maximum: Int) -> fn(Int) -> Result(Int, String) {
  fn(input) {
    case input < maximum {
      True -> Ok(input)
      False -> Error("Must be less than " <> int.to_string(maximum))
    }
  }
}

pub fn must_be_accepted(input: Bool) -> Result(Bool, String) {
  case input {
    True -> Ok(input)
    False -> Error("Must be accepted")
  }
}

//
// Helper functions
//

fn get_values(form: FormValidator(output)) -> Dict(String, String) {
  case form {
    InvalidForm(values, _) -> values
    ValidForm(values, _) -> values
  }
}
