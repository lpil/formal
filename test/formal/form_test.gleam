import formal/nua as form

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

    use tags <- form.multifield("tag", form.parse_list(form.parse_string))
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
