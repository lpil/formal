import gleam/function
import gleam/dict
import gleeunit
import gleeunit/should
import formal/form.{type FormState, FormState}

pub fn main() {
  gleeunit.main()
}

pub type Person {
  Person(email: String, name: String, age: Int, tags: List(String))
}

fn person_form(values: List(#(String, String))) -> Result(Person, FormState) {
  form.decoding(function.curry4(Person))
  |> form.with_values(values)
  |> form.field(
    "email",
    form.string
      |> form.and(form.must_not_be_empty)
      |> form.and(form.must_be_an_email),
  )
  |> form.field(
    "name",
    form.string
      |> form.and(form.must_not_be_empty)
      |> form.and(must_not_be_rude_name),
  )
  |> form.field(
    "age",
    form.int
      |> form.and(
        form.must_be_greater_int_than(-1)
        |> form.message("Must have been born"),
      )
      |> form.and(form.must_be_lesser_int_than(130)),
  )
  |> form.multifield("tags", form.list(form.string))
  |> form.finish
}

fn must_not_be_rude_name(name: String) -> Result(String, String) {
  case name {
    "bums" -> Error("Is not an acceptable name")
    _ -> Ok(name)
  }
}

pub fn person_form_empty_test() {
  []
  |> person_form
  |> should.equal(
    Error(FormState(
      dict.from_list([]),
      dict.from_list([
        #("age", "Must be a whole number"),
        #("name", "Must not be blank"),
        #("email", "Must not be blank"),
      ]),
    )),
  )
}

pub fn person_form_no_email_test() {
  let values = [#("name", "Joan"), #("age", "34")]
  values
  |> person_form
  |> should.equal(
    Error(FormState(
      dict.from_list([#("name", ["Joan"]), #("age", ["34"])]),
      dict.from_list([#("email", "Must not be blank")]),
    )),
  )
  [#("name", "Joan"), #("age", "34")]
}

pub fn person_form_invalid_email_test() {
  let values = [#("name", "Joan"), #("age", "34"), #("email", "a@a@a")]
  values
  |> person_form
  |> should.equal(
    Error(FormState(
      dict.from_list([
        #("name", ["Joan"]),
        #("age", ["34"]),
        #("email", ["a@a@a"]),
      ]),
      dict.from_list([#("email", "Must be an email")]),
    )),
  )
}

pub fn person_form_custom_message_test() {
  let values = [#("name", "Joan"), #("age", "-1"), #("email", "a@example.com")]
  values
  |> person_form
  |> should.equal(
    Error(FormState(
      dict.from_list([
        #("name", ["Joan"]),
        #("age", ["-1"]),
        #("email", ["a@example.com"]),
      ]),
      dict.from_list([#("age", "Must have been born")]),
    )),
  )
}

pub fn person_form_ok_test() {
  [#("name", "Joan"), #("age", "34"), #("email", "a@example.com")]
  |> person_form
  |> should.equal(
    Ok(Person(name: "Joan", email: "a@example.com", age: 34, tags: [])),
  )
}

pub fn person_form_extra_field_test() {
  [
    #("name", "Joan"),
    #("admin", "on"),
    #("age", "34"),
    #("email", "a@example.com"),
  ]
  |> person_form
  |> should.equal(
    Ok(Person(name: "Joan", email: "a@example.com", age: 34, tags: [])),
  )
}

pub fn person_form_multiple_values_test() {
  [
    #("name", "Joan"),
    #("admin", "on"),
    #("age", "34"),
    #("email", "a@example.com"),
    #("tags", "a"),
    #("tags", "b"),
    #("tags", "c"),
  ]
  |> person_form
  |> should.equal(
    Ok(
      Person(name: "Joan", email: "a@example.com", age: 34, tags: [
        "a", "b", "c",
      ]),
    ),
  )
}

pub fn new_test() {
  form.new()
  |> should.equal(FormState(dict.new(), dict.new()))
}

pub fn and_ok_ok_test() {
  let check =
    fn(in) { Ok(in) }
    |> form.and(fn(in) { Ok(in) })
  check(1)
  |> should.equal(Ok(1))
}

pub fn and_ok_error_test() {
  let check =
    fn(in) { Ok(in) }
    |> form.and(fn(_) { Error("2") })
  check(1)
  |> should.equal(Error("2"))
}

pub fn and_error_ok_test() {
  let check =
    fn(_) { Error("1") }
    |> form.and(fn(_) { panic as "This should not be called" })
  check(1)
  |> should.equal(Error("1"))
}

pub fn message_ok_test() {
  let check =
    fn(_) { Ok(1) }
    |> form.message("2")
  check(1)
  |> should.equal(Ok(1))
}

pub fn message_error_test() {
  let check =
    fn(_) { Error("1") }
    |> form.message("2")
  check(1)
  |> should.equal(Error("2"))
}

pub fn string_ok_test() {
  form.string("1")
  |> should.equal(Ok("1"))
}

pub fn int_ok_test() {
  form.int("1")
  |> should.equal(Ok(1))
}

pub fn int_error_test() {
  form.int("a")
  |> should.equal(Error("Must be a whole number"))
}

pub fn float_ok_test() {
  form.float("1.0")
  |> should.equal(Ok(1.0))
}

pub fn float_error_test() {
  form.float("a")
  |> should.equal(Error("Must be a number with a decimal point"))
}

pub fn number_ok_test() {
  form.number("1.0")
  |> should.equal(Ok(1.0))
}

pub fn number_error_test() {
  form.number("a")
  |> should.equal(Error("Must be a number"))
}

pub fn number_ok_int_test() {
  form.number("1")
  |> should.equal(Ok(1.0))
}

pub fn bool_on_test() {
  form.bool("on")
  |> should.equal(Ok(True))
}

pub fn bool_empty_test() {
  form.bool("")
  |> should.equal(Ok(False))
}

pub fn bool_false_test() {
  form.bool("a")
  |> should.equal(Ok(False))
}

pub fn must_not_be_empty_ok_test() {
  form.must_not_be_empty("a")
  |> should.equal(Ok("a"))
}

pub fn must_not_be_empty_error_test() {
  form.must_not_be_empty("")
  |> should.equal(Error("Must not be blank"))
}

pub fn must_be_an_email_ok_test() {
  form.must_be_an_email("hello@example.com")
  |> should.equal(Ok("hello@example.com"))
}

pub fn must_be_an_email_error_test() {
  form.must_be_an_email("hello")
  |> should.equal(Error("Must be an email"))
}

pub fn must_be_greater_int_than_ok_test() {
  form.must_be_greater_int_than(1)(2)
  |> should.equal(Ok(2))
}

pub fn must_be_greater_int_than_error_test() {
  form.must_be_greater_int_than(1)(1)
  |> should.equal(Error("Must be greater than 1"))
}

pub fn must_be_lesser_int_than_ok_test() {
  form.must_be_lesser_int_than(1)(0)
  |> should.equal(Ok(0))
}

pub fn must_be_lesser_int_than_error_test() {
  form.must_be_lesser_int_than(1)(1)
  |> should.equal(Error("Must be less than 1"))
}

pub fn must_be_greater_float_than_ok_test() {
  form.must_be_greater_float_than(1.0)(2.0)
  |> should.equal(Ok(2.0))
}

pub fn must_be_greater_float_than_error_test() {
  form.must_be_greater_float_than(1.0)(1.0)
  |> should.equal(Error("Must be greater than 1.0"))
}

pub fn must_be_lesser_float_than_ok_test() {
  form.must_be_lesser_float_than(1.0)(0.0)
  |> should.equal(Ok(0.0))
}

pub fn must_be_lesser_float_than_error_test() {
  form.must_be_lesser_float_than(1.0)(1.0)
  |> should.equal(Error("Must be less than 1.0"))
}

pub fn must_be_accepted_ok_test() {
  form.must_be_accepted(True)
  |> should.equal(Ok(True))
}

pub fn must_be_accepted_error_test() {
  form.must_be_accepted(False)
  |> should.equal(Error("Must be accepted"))
}

pub fn must_equal_ok_test() {
  form.must_equal(1, "wibble")(1)
  |> should.equal(Ok(1))
}

pub fn must_equal_error_test() {
  form.must_equal(1, "wibble")(2)
  |> should.equal(Error("wibble"))
}

pub fn must_be_string_longer_than_ok_test() {
  form.must_be_string_longer_than(2)("abc")
  |> should.equal(Ok("abc"))
}

pub fn must_be_string_longer_than_error_test() {
  form.must_be_string_longer_than(2)("ab")
  |> should.equal(Error("Must be longer than 2 characters"))
}
