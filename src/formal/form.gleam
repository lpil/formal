import gleam/dict.{type Dict}
import gleam/int
import gleam/float
import gleam/list
import gleam/result
import gleam/string
import gleam/option

/// An invalid or unfinished form. This is either created by the `new`
/// function, which creates a new empty form, or by the `finish` function when
/// the validation failed, returning the invalid form.
///
pub type FormState {
  FormState(values: Dict(String, List(String)), errors: Dict(String, String))
}

/// A collection of validations that decode data from a form into a typed value.
///
/// See the module documentation for an overview of how to use this type to
/// validate a form.
///
pub opaque type FormValidator(output) {
  InvalidForm(values: Dict(String, List(String)), errors: Dict(String, String))
  ValidForm(values: Dict(String, List(String)), output: output)
}

/// Set the constructor that is used to create the success value if the form
/// decodes and validates successfully.
///
/// You will want to use a curried constructor function here. The `curry*`
/// functions in the `gleam/function` standard library module can be used to
/// help with this.
///
pub fn decoding(into constructor: fn(a) -> rest) -> FormValidator(fn(a) -> rest) {
  ValidForm(dict.new(), constructor)
}

/// Create a new empty form.
///
/// You likely want to use this when rendering a page containing a new form.
///
pub fn new() -> FormState {
  FormState(dict.new(), dict.new())
}

/// Set the values from the form submission to be validated.
///
/// HTML forms can have multiple fields with the same name. This function will
/// use the final value with each name, so if you wish to use a different value
/// consider removing the duplicates or using `with_values_dict`.
///
pub fn with_values(
  form: FormValidator(out),
  values: List(#(String, String)),
) -> FormValidator(out) {
  values
  |> list.fold_right(dict.new(), fn(acc, pair) {
    dict.update(acc, pair.0, fn(previous) {
      [pair.1, ..option.unwrap(previous, [])]
    })
  })
  |> with_values_dict(form, _)
}

/// Set the values from the form submission to be validated.
///
pub fn with_values_dict(
  form: FormValidator(out),
  values: Dict(String, List(String)),
) -> FormValidator(out) {
  case form {
    InvalidForm(_, errors) -> InvalidForm(values, errors)
    ValidForm(_, output) -> ValidForm(values, output)
  }
}

/// Add the next field to be decoded and validated from the form, corresponding
/// to the next argument to the constructor.
///
/// This function is useful when you have multiple inputs with the same name in
/// the form, and you most likely want to use it with the `list` decoder
/// function. When there is only a single input with the given name in the form
/// then the `field` function is more appropriate.
///
pub fn multifield(
  form: FormValidator(fn(t) -> rest),
  name: String,
  decoder: fn(List(String)) -> Result(t, String),
) -> FormValidator(rest) {
  let result =
    form
    |> get_values
    |> dict.get(name)
    |> result.unwrap([])
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

/// Add the next field to be decoded and validated from the form, corresponding
/// to the next argument to the constructor.
///
pub fn field(
  form: FormValidator(fn(t) -> rest),
  name: String,
  decoder: fn(String) -> Result(t, String),
) -> FormValidator(rest) {
  multifield(form, name, fn(value) {
    value
    |> list.first
    |> result.unwrap("")
    |> decoder
  })
}

/// Finish the form validation, returning the success value built using the
/// constructor, or the invalid form containing the values and errors, which
/// can be used to render the form again to the user.
///
pub fn finish(form: FormValidator(output)) -> Result(output, FormState) {
  case form {
    InvalidForm(values, errors) -> Error(FormState(values, errors))
    ValidForm(_, output) -> Ok(output)
  }
}

//
// Decoders
//

/// Add an additional validation step to the field decoder function.
///
/// This function behaves similar to the `try` function in the standard library
/// `gleam/result` module.
///
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

/// Set a custom error message for a field decoder, overwriting the previous
/// error message if there is one at this point in the decoder, doing nothing
/// if the decoder is successful.
///
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

/// Decode the field value as a string.
///
/// # Examples
///
/// ```gleam
/// string("hello")
/// # -> Ok("hello")
/// ```
///
pub fn string(input: String) -> Result(String, String) {
  Ok(string.trim(input))
}

/// Decode all the values for a field as a given type. This is useful with the
/// `multifield` function when there are multiple inputs with the same name in
/// the form.
///
/// # Examples
///
/// ```gleam
/// int("123")
/// # -> Ok(123)
/// ```
///
/// ```gleam
/// int("ok")
/// # -> Error("Must be a whole number")
/// ```
///
pub fn list(
  of decoder: fn(String) -> Result(t, String),
) -> fn(List(String)) -> Result(List(t), String) {
  list.try_map(_, decoder)
}

/// Decode the field value as an int.
///
/// # Examples
///
/// ```gleam
/// int("123")
/// # -> Ok(123)
/// ```
///
/// ```gleam
/// int("ok")
/// # -> Error("Must be a whole number")
/// ```
///
pub fn int(input: String) -> Result(Int, String) {
  case int.parse(input) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Must be a whole number")
  }
}

/// Decode the field value as a float.
///
/// The input value must have a decimal point.
///
/// # Examples
///
/// ```gleam
/// float("12.34")
/// # -> Ok(123)
/// ```
///
/// ```gleam
/// float("1")
/// # -> Error("Must be a number with a decimal point")
/// ```
///
/// ```gleam
/// float("ok")
/// # -> Error("Must be a number with a decimal point")
/// ```
///
pub fn float(input: String) -> Result(Float, String) {
  case float.parse(input) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Must be a number with a decimal point")
  }
}

/// Decode the field value as a float.
///
/// The decimal point is optional.
///
/// # Examples
///
/// ```gleam
/// number("12.34")
/// # -> Ok(123)
/// ```
///
/// ```gleam
/// number("1")
/// # -> Ok(1.0)
/// ```
///
/// ```gleam
/// number("ok")
/// # -> Error("Must be a number")
/// ```
///
pub fn number(input: String) -> Result(Float, String) {
  let result =
    int.parse(input)
    |> result.map(int.to_float)
    |> result.lazy_or(fn() { float.parse(input) })
  case result {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Must be a number")
  }
}

/// Decode the field value as a bool.
///
/// The input value must be "on" to be considered true as this is the value
/// that HTML checkboxes use when checked.
///
/// # Examples
///
/// ```gleam
/// bool("on")
/// # -> Ok(True)
/// ```
///
/// ```gleam
/// bool("true")
/// # -> Ok(False)
/// ```
///
/// ```gleam
/// bool("")
/// # -> Ok(False)
/// ```
///
pub fn bool(input: String) -> Result(Bool, String) {
  case input {
    "on" -> Ok(True)
    _ -> Ok(False)
  }
}

/// Assert that the string input must not be empty, returning an error if it
/// is.
///
/// # Examples
///
/// ```gleam
/// must_not_be_empty("Hello")
/// # -> Ok("Hello")
/// ```
///
/// ```gleam
/// must_not_be_empty("")
/// # -> Error("Must not be blank")
/// ```
///
pub fn must_not_be_empty(input: String) -> Result(String, String) {
  case input {
    "" -> Error("Must not be blank")
    _ -> Ok(input)
  }
}

/// Assert that the string input looks like an email address.
///
/// It could still be an invalid email address even if it looks like one. To
/// validate an email address is valid you will need to send an email to it and
/// ensure your user receives it.
///
/// # Examples
///
/// ```gleam
/// must_be_an_email("hello@example.com")
/// # -> Ok("hello@example.com")
/// ```
///
/// ```gleam
/// must_be_an_email("Something")
/// # -> Error("Must be an email")
/// ```
///
pub fn must_be_an_email(input: String) -> Result(String, String) {
  case string.split(input, "@") {
    [_, _] -> Ok(input)
    _ -> Error("Must be an email")
  }
}

/// Assert that the int input is greater than the given minimum.
///
/// It could still be an invalid email address even if it looks like one. To
/// validate an email address is valid you will need to send an email to it and
/// ensure your user receives it.
///
/// # Examples
///
/// ```gleam
/// let check = must_be_greater_int_than(10)
/// check(12)
/// # -> Ok(12)
/// ```
///
/// ```gleam
/// let check = must_be_greater_int_than(10)
/// check(2)
/// # -> Error("Must be greater than 10")
/// ```
///
pub fn must_be_greater_int_than(minimum: Int) -> fn(Int) -> Result(Int, String) {
  fn(input) {
    case input > minimum {
      True -> Ok(input)
      False -> Error("Must be greater than " <> int.to_string(minimum))
    }
  }
}

/// Assert that the int input is greater than the given minimum.
///
/// It could still be an invalid email address even if it looks like one. To
/// validate an email address is valid you will need to send an email to it and
/// ensure your user receives it.
///
/// # Examples
///
/// ```gleam
/// let check = must_be_lesser_int_than(10)
/// check(12)
/// # -> Ok(12)
/// ```
///
/// ```gleam
/// let check = must_be_lesser_int_than(10)
/// check(2)
/// # -> Error("Must be less than 10")
/// ```
///
pub fn must_be_lesser_int_than(maximum: Int) -> fn(Int) -> Result(Int, String) {
  fn(input) {
    case input < maximum {
      True -> Ok(input)
      False -> Error("Must be less than " <> int.to_string(maximum))
    }
  }
}

/// Assert that the float input is greater than the given minimum.
///
/// It could still be an invalid email address even if it looks like one. To
/// validate an email address is valid you will need to send an email to it and
/// ensure your user receives it.
///
/// # Examples
///
/// ```gleam
/// let check = must_be_greater_float_than(3.3)
/// check(4.1)
/// # -> Ok(3.3)
/// ```
///
/// ```gleam
/// let check = must_be_greater_float_than(3.3)
/// check(2.0)
/// # -> Error("Must be greater than 3.3")
/// ```
///
pub fn must_be_greater_float_than(
  minimum: Float,
) -> fn(Float) -> Result(Float, String) {
  fn(input) {
    case input >. minimum {
      True -> Ok(input)
      False -> Error("Must be greater than " <> float.to_string(minimum))
    }
  }
}

/// Assert that the float input is greater than the given minimum.
///
/// It could still be an invalid email address even if it looks like one. To
/// validate an email address is valid you will need to send an email to it and
/// ensure your user receives it.
///
/// # Examples
///
/// ```gleam
/// let check = must_be_lesser_float_than(10)
/// check(12)
/// # -> Ok(12)
/// ```
///
/// ```gleam
/// let check = must_be_lesser_float_than(10)
/// check(2)
/// # -> Error("Must be less than 10")
/// ```
///
pub fn must_be_lesser_float_than(
  maximum: Float,
) -> fn(Float) -> Result(Float, String) {
  fn(input) {
    case input <. maximum {
      True -> Ok(input)
      False -> Error("Must be less than " <> float.to_string(maximum))
    }
  }
}

/// Assert that the bool input is true. This is expected to be used with
/// checkboxes and has an error message that reflects that.
///
/// # Examples
///
/// ```gleam
/// must_be_accepted(True)
/// # -> Ok(True)
/// ```
///
/// ```gleam
/// must_be_accepted(False)
/// # -> Error("Must be accepted")
/// ```
///
pub fn must_be_accepted(input: Bool) -> Result(Bool, String) {
  case input {
    True -> Ok(input)
    False -> Error("Must be accepted")
  }
}

/// Assert that the bool input is true. This is expected to be used with
/// checkboxes and has an error message that reflects that.
///
/// # Examples
///
/// ```gleam
/// let check = must_equal(42, "Must be the answer to everything")
/// check(42)
/// # -> Ok(42)
/// ```
///
/// ```gleam
/// let check = must_equal(42, "Must be the answer to everything")
/// check(2)
/// # -> Error("Must be the answer to everything")
/// ```
///
pub fn must_equal(
  expected: t,
  because error_message: String,
) -> fn(t) -> Result(t, String) {
  fn(input) {
    case input == expected {
      True -> Ok(input)
      False -> Error(error_message)
    }
  }
}

//
// Helper functions
//

fn get_values(form: FormValidator(output)) -> Dict(String, List(String)) {
  case form {
    InvalidForm(values, _) -> values
    ValidForm(values, _) -> values
  }
}
