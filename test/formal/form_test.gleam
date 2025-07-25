import formal/form
import gleam/option
import gleam/time/calendar
import gleam/uri

pub type Person {
  Person(email: String, name: String, age: Int, tags: List(String))
}

fn person_form() -> form.Form(Person) {
  form.new({
    use email <- form.field("email", { form.parse_email })

    use name <- form.field("name", {
      form.parse_string
      |> form.check_not_empty
      |> form.check(name_not_rude)
    })

    use age <- form.field("age", {
      form.parse_int
      |> form.check_int_less_than(130)
      |> form.check_int_more_than(-1)
    })

    use tags <- form.field("tag", form.parse_list(form.parse_string))
    form.success(Person(email:, name:, age:, tags:))
  })
  |> form.language(form.en_gb)
}

fn update_person_form(person: Person) -> form.Form(Person) {
  person_form()
  |> form.add_string("email", person.email)
  |> form.add_string("name", person.name)
  |> form.add_int("age", person.age)
}

fn name_not_rude(name: String) -> Result(String, String) {
  case name {
    "bums" -> Error("is not an acceptable name")
    _ -> Ok(name)
  }
}

pub fn person_form_empty_test() {
  let values = []
  let assert Error(form) =
    person_form()
    |> form.add_values(values)
    |> form.run

  assert form.all_errors(form)
    == [
      #("age", [form.MustBeInt]),
      #("name", [form.MustBePresent]),
      #("email", [form.MustBeEmail]),
    ]

  assert form.all_values(form) == []
}

pub fn person_form_ok_test() {
  let values = [
    #("age", "100"),
    #("name", "Wibble"),
    #("email", "wib@example.com"),
    #("tag", "one"),
    #("tag", "two"),
  ]
  assert person_form()
    |> form.add_values(values)
    |> form.run
    == Ok(
      Person(email: "wib@example.com", name: "Wibble", age: 100, tags: [
        "one",
        "two",
      ]),
    )
}

pub fn person_form_existing_test() {
  let form =
    update_person_form(
      Person(email: "lúí@example.com", name: "Lúí", age: 100, tags: ["gleam"]),
    )

  assert form.all_values(form)
    == [#("age", "100"), #("name", "Lúí"), #("email", "lúí@example.com")]

  assert form.all_errors(form) == []

  let assert Error(form) =
    form
    |> form.add_int("age", -1)
    |> form.add_string("email", "what")
    |> form.run

  assert form.all_values(form)
    == [
      #("email", "what"),
      #("age", "-1"),
      #("age", "100"),
      #("name", "Lúí"),
      #("email", "lúí@example.com"),
    ]

  assert form.all_errors(form)
    == [#("age", [form.MustBeIntMoreThan(-1)]), #("email", [form.MustBeEmail])]
}

pub fn parse_string_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_string)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "hello!")
    |> form.run
    == Ok("hello!")
  assert form
    |> form.add_string("data", "first")
    |> form.add_string("data", "second")
    |> form.run
    == Ok("second")
  assert form
    |> form.run
    == Ok("")
}

pub fn parse_int_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_int)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "123")
    |> form.run
    == Ok(123)
  assert form
    |> form.add_string("data", "one")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "one")
      |> form.add_error("data", form.MustBeInt),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeInt))
}

pub fn parse_float_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_float)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "123.45")
    |> form.run
    == Ok(123.45)
  assert form
    |> form.add_string("data", "123")
    |> form.run
    == Ok(123.0)
  assert form
    |> form.add_string("data", "not_a_float")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not_a_float")
      |> form.add_error("data", form.MustBeFloat),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeFloat))
}

pub fn parse_phone_number_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_phone_number)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "+1 (555) 123-4567")
    |> form.run
    == Ok("15551234567")
  assert form
    |> form.add_string("data", "5551234567")
    |> form.run
    == Ok("5551234567")
  assert form
    |> form.add_string("data", "123")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "123")
      |> form.add_error("data", form.MustBePhoneNumber),
    )
  assert form
    |> form.add_string("data", "not_a_phone")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not_a_phone")
      |> form.add_error("data", form.MustBePhoneNumber),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBePhoneNumber))
}

pub fn parse_url_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_url)
      form.success(x)
    })
  let assert Ok(uri) = uri.parse("https://example.com")
  assert form
    |> form.add_string("data", "https://example.com")
    |> form.run
    == Ok(uri)
  let assert Ok(uri) = uri.parse("http://localhost:8080/path")
  assert form
    |> form.add_string("data", "http://localhost:8080/path")
    |> form.run
    == Ok(uri)
  assert form
    |> form.add_string("data", "ht!tp://invalid")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "ht!tp://invalid")
      |> form.add_error("data", form.MustBeUrl),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeUrl))
}

pub fn parse_date_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_date)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "2023-12-25")
    |> form.run
    == Ok(calendar.Date(2023, calendar.December, 25))
  assert form
    |> form.add_string("data", "1990-01-01")
    |> form.run
    == Ok(calendar.Date(1990, calendar.January, 1))
  assert form
    |> form.add_string("data", "not-a-date")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not-a-date")
      |> form.add_error("data", form.MustBeDate),
    )
  assert form
    |> form.add_string("data", "2023-13-40")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "2023-13-40")
      |> form.add_error("data", form.MustBeDate),
    )
  assert form
    |> form.add_string("data", "2023-02-29")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "2023-02-29")
      |> form.add_error("data", form.MustBeDate),
    )
  assert form
    |> form.add_string("data", "2023-04-31")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "2023-04-31")
      |> form.add_error("data", form.MustBeDate),
    )
  assert form
    |> form.add_string("data", "2024-02-29")
    |> form.run
    == Ok(calendar.Date(2024, calendar.February, 29))
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeDate))
}

pub fn parse_time_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_time)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "14:30")
    |> form.run
    == Ok(calendar.TimeOfDay(14, 30, 0, 0))
  assert form
    |> form.add_string("data", "09:15:30")
    |> form.run
    == Ok(calendar.TimeOfDay(9, 15, 30, 0))
  assert form
    |> form.add_string("data", "23:59:59")
    |> form.run
    == Ok(calendar.TimeOfDay(23, 59, 59, 0))
  assert form
    |> form.add_string("data", "00:00")
    |> form.run
    == Ok(calendar.TimeOfDay(0, 0, 0, 0))
  assert form
    |> form.add_string("data", "not-a-time")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not-a-time")
      |> form.add_error("data", form.MustBeTime),
    )
  assert form
    |> form.add_string("data", "25:00")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "25:00")
      |> form.add_error("data", form.MustBeTime),
    )
  assert form
    |> form.add_string("data", "12:60")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "12:60")
      |> form.add_error("data", form.MustBeTime),
    )
  assert form
    |> form.add_string("data", "12:30:60")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "12:30:60")
      |> form.add_error("data", form.MustBeTime),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeTime))
}

pub fn parse_date_time_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_date_time)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "2023-12-25T14:30")
    |> form.run
    == Ok(#(
      calendar.Date(2023, calendar.December, 25),
      calendar.TimeOfDay(14, 30, 0, 0),
    ))
  assert form
    |> form.add_string("data", "2023-12-25T14:30:45")
    |> form.run
    == Ok(#(
      calendar.Date(2023, calendar.December, 25),
      calendar.TimeOfDay(14, 30, 45, 0),
    ))
  assert form
    |> form.add_string("data", "2024-02-29T23:59:59")
    |> form.run
    == Ok(#(
      calendar.Date(2024, calendar.February, 29),
      calendar.TimeOfDay(23, 59, 59, 0),
    ))
  assert form
    |> form.add_string("data", "1990-01-01T00:00")
    |> form.run
    == Ok(#(
      calendar.Date(1990, calendar.January, 1),
      calendar.TimeOfDay(0, 0, 0, 0),
    ))
  assert form
    |> form.add_string("data", "not-a-datetime")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not-a-datetime")
      |> form.add_error("data", form.MustBeDateTime),
    )
  assert form
    |> form.add_string("data", "2023-12-25")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "2023-12-25")
      |> form.add_error("data", form.MustBeDateTime),
    )
  assert form
    |> form.add_string("data", "14:30:00")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "14:30:00")
      |> form.add_error("data", form.MustBeDateTime),
    )
  assert form
    |> form.add_string("data", "2023-13-25T14:30")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "2023-13-25T14:30")
      |> form.add_error("data", form.MustBeDateTime),
    )
  assert form
    |> form.add_string("data", "2023-12-25T25:30")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "2023-12-25T25:30")
      |> form.add_error("data", form.MustBeDateTime),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeDateTime))
}

pub fn parse_colour_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_colour)
      form.success(x)
    })
  assert form
    |> form.add_string("data", "#FF0000")
    |> form.run
    == Ok("#FF0000")
  assert form
    |> form.add_string("data", "#00ff00")
    |> form.run
    == Ok("#00ff00")
  assert form
    |> form.add_string("data", "#0000FF")
    |> form.run
    == Ok("#0000FF")
  assert form
    |> form.add_string("data", "#123abc")
    |> form.run
    == Ok("#123abc")
  assert form
    |> form.add_string("data", "#000000")
    |> form.run
    == Ok("#000000")
  assert form
    |> form.add_string("data", "#FFFFFF")
    |> form.run
    == Ok("#FFFFFF")
  assert form
    |> form.add_string("data", "not-a-color")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not-a-color")
      |> form.add_error("data", form.MustBeColour),
    )
  assert form
    |> form.add_string("data", "FF0000")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "FF0000")
      |> form.add_error("data", form.MustBeColour),
    )
  assert form
    |> form.add_string("data", "#FF00")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "#FF00")
      |> form.add_error("data", form.MustBeColour),
    )
  assert form
    |> form.add_string("data", "#GG0000")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "#GG0000")
      |> form.add_error("data", form.MustBeColour),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeColour))
}

pub fn parse_checkbox_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_checkbox)
      form.success(x)
    })
  assert form
    |> form.run
    == Ok(False)
  assert form
    |> form.add_string("data", "")
    |> form.run
    == Ok(True)
  assert form
    |> form.add_string("data", "on")
    |> form.run
    == Ok(True)
  assert form
    |> form.add_string("data", "true")
    |> form.run
    == Ok(True)
  assert form
    |> form.add_string("data", "false")
    |> form.run
    == Ok(True)
  assert form
    |> form.add_string("data", "1")
    |> form.run
    == Ok(True)
}

pub fn check_accepted_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_checkbox
        |> form.check_accepted
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "on")
    |> form.run
    == Ok(True)
  assert form
    |> form.add_string("data", "yes")
    |> form.run
    == Ok(True)
  assert form
    |> form.add_string("data", "")
    |> form.run
    == Ok(True)
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeAccepted))
}

pub fn check_confirms_test() {
  let form =
    form.new({
      use password <- form.field("password", { form.parse_string })
      use confirmation <- form.field("confirmation", {
        form.parse_string
        |> form.check_confirms(password)
      })
      form.success(#(password, confirmation))
    })
  assert form
    |> form.add_string("password", "123")
    |> form.add_string("confirmation", "123")
    |> form.run
    == Ok(#("123", "123"))
  assert form
    |> form.add_string("password", "123")
    |> form.run
    == form
    |> form.add_string("password", "123")
    |> form.add_error("confirmation", form.MustConfirm)
    |> Error
}

pub fn check_not_empty_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_string
        |> form.check_not_empty
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "hello")
    |> form.run
    == Ok("hello")
  assert form
    |> form.add_string("data", "world")
    |> form.run
    == Ok("world")
  assert form
    |> form.add_string("data", "")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "")
      |> form.add_error("data", form.MustBePresent),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBePresent))
}

pub fn check_int_less_than_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_int
        |> form.check_int_less_than(100)
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "50")
    |> form.run
    == Ok(50)
  assert form
    |> form.add_string("data", "99")
    |> form.run
    == Ok(99)
  assert form
    |> form.add_string("data", "-10")
    |> form.run
    == Ok(-10)
  assert form
    |> form.add_string("data", "100")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "100")
      |> form.add_error("data", form.MustBeIntLessThan(100)),
    )
  assert form
    |> form.add_string("data", "150")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "150")
      |> form.add_error("data", form.MustBeIntLessThan(100)),
    )
  assert form
    |> form.add_string("data", "not_an_int")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not_an_int")
      |> form.add_error("data", form.MustBeInt),
    )
}

pub fn check_int_more_than_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_int
        |> form.check_int_more_than(0)
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "10")
    |> form.run
    == Ok(10)
  assert form
    |> form.add_string("data", "1")
    |> form.run
    == Ok(1)
  assert form
    |> form.add_string("data", "100")
    |> form.run
    == Ok(100)
  assert form
    |> form.add_string("data", "0")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "0")
      |> form.add_error("data", form.MustBeIntMoreThan(0)),
    )
  assert form
    |> form.add_string("data", "-5")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "-5")
      |> form.add_error("data", form.MustBeIntMoreThan(0)),
    )
  assert form
    |> form.add_string("data", "not_an_int")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not_an_int")
      |> form.add_error("data", form.MustBeInt),
    )
}

pub fn check_string_length_more_than_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_string
        |> form.check_string_length_more_than(5)
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "hello world")
    |> form.run
    == Ok("hello world")
  assert form
    |> form.add_string("data", "password")
    |> form.run
    == Ok("password")
  assert form
    |> form.add_string("data", "123456")
    |> form.run
    == Ok("123456")
  assert form
    |> form.add_string("data", "hello")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "hello")
      |> form.add_error("data", form.MustBeStringLengthMoreThan(5)),
    )
  assert form
    |> form.add_string("data", "hi")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "hi")
      |> form.add_error("data", form.MustBeStringLengthMoreThan(5)),
    )
  assert form
    |> form.add_string("data", "")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "")
      |> form.add_error("data", form.MustBeStringLengthMoreThan(5)),
    )
  assert form
    |> form.run
    == Error(form |> form.add_error("data", form.MustBeStringLengthMoreThan(5)))
}

pub fn check_string_length_less_than_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_string
        |> form.check_string_length_less_than(10)
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "hello")
    |> form.run
    == Ok("hello")
  assert form
    |> form.add_string("data", "short")
    |> form.run
    == Ok("short")
  assert form
    |> form.add_string("data", "")
    |> form.run
    == Ok("")
  assert form
    |> form.add_string("data", "exactly10!")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "exactly10!")
      |> form.add_error("data", form.MustBeStringLengthLessThan(10)),
    )
  assert form
    |> form.add_string("data", "this is way too long")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "this is way too long")
      |> form.add_error("data", form.MustBeStringLengthLessThan(10)),
    )
  assert form
    |> form.run
    == Ok("")
}

pub fn check_float_more_than_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_float
        |> form.check_float_more_than(10.0)
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "15.5")
    |> form.run
    == Ok(15.5)
  assert form
    |> form.add_string("data", "10.1")
    |> form.run
    == Ok(10.1)
  assert form
    |> form.add_string("data", "100.99")
    |> form.run
    == Ok(100.99)
  assert form
    |> form.add_string("data", "10.0")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "10.0")
      |> form.add_error("data", form.MustBeFloatMoreThan(10.0)),
    )
  assert form
    |> form.add_string("data", "5.5")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "5.5")
      |> form.add_error("data", form.MustBeFloatMoreThan(10.0)),
    )
  assert form
    |> form.add_string("data", "not_a_float")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not_a_float")
      |> form.add_error("data", form.MustBeFloat),
    )
}

pub fn check_float_less_than_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_float
        |> form.check_float_less_than(100.0)
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "50.5")
    |> form.run
    == Ok(50.5)
  assert form
    |> form.add_string("data", "99.9")
    |> form.run
    == Ok(99.9)
  assert form
    |> form.add_string("data", "0.1")
    |> form.run
    == Ok(0.1)
  assert form
    |> form.add_string("data", "100.0")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "100.0")
      |> form.add_error("data", form.MustBeFloatLessThan(100.0)),
    )
  assert form
    |> form.add_string("data", "150.5")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "150.5")
      |> form.add_error("data", form.MustBeFloatLessThan(100.0)),
    )
  assert form
    |> form.add_string("data", "not_a_float")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "not_a_float")
      |> form.add_error("data", form.MustBeFloat),
    )
}

pub fn en_gb_test() {
  assert form.en_gb(form.MustBeEmail) == "must be an email"
  assert form.en_gb(form.MustBeColour) == "must be a hex colour code"
  assert form.en_gb(form.MustBeFloatLessThan(limit: 5.5))
    == "must be less than 5.5"
}

pub fn en_us_test() {
  assert form.en_us(form.MustBeEmail) == "must be an email"
  assert form.en_us(form.MustBeColour) == "must be a hex color code"
  assert form.en_us(form.MustBeFloatLessThan(limit: 5.5))
    == "must be less than 5.5"
}

pub fn language_test() {
  let assert Error(form) =
    form.new({
      use email <- form.field("colour", form.parse_colour)
      form.success(email)
    })
    |> form.run

  assert form
    |> form.language(form.en_gb)
    |> form.field_error_messages("colour")
    == ["must be a hex colour code"]

  assert form
    |> form.language(form.en_us)
    |> form.field_error_messages("colour")
    == ["must be a hex color code"]
}

pub fn error_text_test() {
  let form =
    form.new({
      use email <- form.field("colour", form.parse_colour)
      form.success(email)
    })
    |> form.add_error("a", form.MustBeDate)
    |> form.add_error("a", form.MustBeFloat)
    |> form.add_error("b", form.CustomError("must be a Pokemon"))

  assert form.field_error_messages(form, "a")
    == ["must be a number", "must be a date"]
  assert form.field_error_messages(form, "b") == ["must be a Pokemon"]
}

pub fn get_values_test() {
  let form =
    form.new({
      use email <- form.field("colour", form.parse_colour)
      form.success(email)
    })
    |> form.add_int("one", 100)
    |> form.add_string("one", "Hello")
    |> form.add_string("two", "Hi!")
  assert form.field_values(form, "one") == ["Hello", "100"]
  assert form.field_values(form, "two") == ["Hi!"]
  assert form.field_values(form, "three") == []
}

pub fn check_test() {
  let must_not_start_with_z = fn(s) {
    case s {
      "z" <> _ -> Error("must not start with z")
      _ -> Ok(s)
    }
  }
  let form =
    form.new({
      use data <- form.field("data", {
        form.parse_string
        |> form.check(must_not_start_with_z)
      })
      form.success(data <> data)
    })
  assert form
    |> form.add_string("data", "123")
    |> form.run
    == Ok("123123")
  assert form
    |> form.add_string("data", "zyx")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "zyx")
      |> form.add_error("data", form.CustomError("must not start with z")),
    )
}

pub fn parse_list_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_list(form.parse_int))
      form.success(x)
    })
  assert form
    |> form.add_int("data", 1)
    |> form.add_int("data", 2)
    |> form.add_int("data", 3)
    |> form.run
    == Ok([3, 2, 1])
  assert form
    |> form.run
    == Ok([])
  assert form
    |> form.add_int("data", 1)
    |> form.add_int("data", 2)
    |> form.add_int("data", 3)
    |> form.add_string("data", "hello")
    |> form.run
    == Error(
      form
      |> form.add_int("data", 1)
      |> form.add_int("data", 2)
      |> form.add_int("data", 3)
      |> form.add_string("data", "hello")
      |> form.add_error("data", form.MustBeInt),
    )
  assert form
    |> form.add_string("data", "")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "")
      |> form.add_error("data", form.MustBeInt),
    )
  assert // Errors are not duplicated
    form
    |> form.add_string("data", "one")
    |> form.add_string("data", "two")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "one")
      |> form.add_string("data", "two")
      |> form.add_error("data", form.MustBeInt),
    )
}

pub fn parse_optional_test() {
  let form =
    form.new({
      use x <- form.field("data", form.parse_optional(form.parse_int))
      form.success(x)
    })
  assert form
    |> form.add_int("data", 1)
    |> form.run
    == Ok(option.Some(1))
  assert form
    |> form.add_string("data", "")
    |> form.run
    == Ok(option.None)
  assert form
    |> form.run
    == Ok(option.None)
  assert form
    |> form.add_string("data", "blah")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "blah")
      |> form.add_error("data", form.MustBeInt),
    )
}

type StarterPokemon {
  Squirtle
  Bulbasaur
  Charmander
}

pub fn parse_test() {
  let form =
    form.new({
      use x <- form.field("starter", {
        form.parse(fn(input) {
          case input {
            ["Squirtle", ..] -> Ok(Squirtle)
            ["Bulbasaur", ..] -> Ok(Bulbasaur)
            ["Charmander", ..] -> Ok(Charmander)
            _ -> Error(#(Squirtle, "must be a starter Pokémon"))
          }
        })
      })
      form.success(x)
    })
  assert form
    |> form.add_string("starter", "Squirtle")
    |> form.run
    == Ok(Squirtle)
  assert form
    |> form.add_string("starter", "Bulbasaur")
    |> form.run
    == Ok(Bulbasaur)
  assert form
    |> form.add_string("starter", "Charmander")
    |> form.run
    == Ok(Charmander)
  assert form
    |> form.add_string("starter", "Wibble")
    |> form.run
    == Error(
      form
      |> form.add_string("starter", "Wibble")
      |> form.add_error(
        "starter",
        form.CustomError("must be a starter Pokémon"),
      ),
    )
}

pub fn parse_short_circuit_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse(fn(input) {
          case input {
            ["zero", ..] -> Ok(0)
            ["one", ..] -> Ok(1)
            ["two", ..] -> Ok(2)
            _ -> Error(#(0, "must be a number"))
          }
        })
        |> form.check_int_less_than(2)
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "zero")
    |> form.run
    == Ok(0)
  assert // Parse fails
    form
    |> form.add_string("data", "Whatever!")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "Whatever!")
      |> form.add_error("data", form.CustomError("must be a number")),
    )
  assert // Check fails
    form
    |> form.add_string("data", "two")
    |> form.run
    == Error(
      form
      |> form.add_string("data", "two")
      |> form.add_error("data", form.MustBeIntLessThan(2)),
    )
}

pub fn map_test() {
  let form =
    form.new({
      use x <- form.field("data", {
        form.parse_string
        |> form.map(fn(x) { #(x, x) })
      })
      form.success(x)
    })
  assert form
    |> form.add_string("data", "Hi!")
    |> form.run
    == Ok(#("Hi!", "Hi!"))
}

pub fn set_values_test() {
  let form =
    form.new(form.success(Nil))
    |> form.set_values([#("a", "1"), #("b", "2")])

  assert form.all_values(form) == [#("a", "1"), #("b", "2")]

  assert form
    |> form.set_values([#("a", "3")])
    |> form.all_values
    == [#("a", "3")]
}

pub fn add_values_test() {
  let form =
    form.new(form.success(Nil))
    |> form.add_values([#("a", "1"), #("b", "2")])

  assert form.all_values(form) == [#("a", "1"), #("b", "2")]

  assert form
    |> form.add_values([#("a", "3")])
    |> form.all_values
    == [#("a", "3"), #("a", "1"), #("b", "2")]
}
