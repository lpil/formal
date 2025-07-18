# formal

Type safe HTML form decoding and validation!

[![Package Version](https://img.shields.io/hexpm/v/formal)](https://hex.pm/packages/formal)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/formal/)

```sh
gleam add formal@3
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
    form.new({
      use email <- form.field("email", form.parse_email)
      use password <- form.field("password", {
        form.parse_string
        |> form.check_string_length_more_than(7)
      })
      SignUp(email: email, password: password)
    })
    |> form.add_values(values)
    |> form.run

  case result {
    Ok(data) -> {
      // Do something with the SignUp value here
    }
    Error(form) -> {
      // Re-render the form with the error messages
    }
  }
}
```

An example of using this library with Wisp and Lustre can be found in
[./example/](https://github.com/lpil/formal/tree/main/example).

Further documentation can be found at <https://hexdocs.pm/formal>.
