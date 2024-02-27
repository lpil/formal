# formal

[![Package Version](https://img.shields.io/hexpm/v/formal)](https://hex.pm/packages/formal)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/formal/)

```sh
gleam add formal
```
```gleam
import formal/form

// Define a type that is to be decoded from the form data
pub type SignUp {
  SignUp(email: String, password: String)
}

// This function takes the list of key-value string pairs that a HTML form
// produces. It then decodes the form data into a SignUp value, ensuring that
// all the fields are present and valid.
//
pub fn handle_form_submission(values: List(#(String, String))) {
  let result = 
    form.decoding(function.curry2(SignUp))
    |> form.with_values(values)
    |> form.field(
      "email",
      form.string
        |> form.and(form.must_not_be_empty)
        |> form.and(form.must_be_an_email),
    )
    |> form.field(
      "password",
      form.string
        |> form.and(form.must_not_be_empty)
        |> form.and(form.must_be_string_longer_than(7))
    )
    |> form.finish

  case result {
    Ok(data) -> {
      // Do something with the SignUp value here
    }
    Error(form_state) -> {
      // Re-render the form with the error messages
    }
  }
}
```

Further documentation can be found at <https://hexdocs.pm/formal>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
