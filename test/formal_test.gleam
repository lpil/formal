import gleam/function
import gleam/dict
import gleeunit
import gleeunit/should
import formal/form.{type FormState, FormState}

pub fn main() {
  gleeunit.main()
}

pub type Person {
  Person(email: String, name: String, age: Int)
}

fn person_form(values: List(#(String, String))) -> Result(Person, FormState) {
  form.decoding(function.curry3(Person))
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
      dict.from_list(values),
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
      dict.from_list(values),
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
      dict.from_list(values),
      dict.from_list([#("age", "Must have been born")]),
    )),
  )
}

pub fn person_form_ok_test() {
  [#("name", "Joan"), #("age", "34"), #("email", "a@example.com")]
  |> person_form
  |> should.equal(Ok(Person(name: "Joan", email: "a@example.com", age: 34)))
}

pub fn person_form_extra_field_test() {
  [
    #("name", "Joan"),
    #("admin", "on"),
    #("age", "34"),
    #("email", "a@example.com"),
  ]
  |> person_form
  |> should.equal(Ok(Person(name: "Joan", email: "a@example.com", age: 34)))
}
