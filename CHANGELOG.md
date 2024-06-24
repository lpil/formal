# Changelog

## Unreleased

- The `formal/form` gains the `initial_values` function for creating a
  `FormState` with some initial values. This may be useful for rendering an
  unvalidated form.
- The `formal/form` gains the `value` and `field_state` convenience functions
  for getting values and errors from a `FormState`.
- The `FormState` type has been renamed to `Form`.

## v1.1.0 - 2024-06-24

- The `formal/form` gains the `parameter` function. This function is intended to
  be used with `use` expressions to create a constructor function to be passed
  to the `decoding` function.

## v1.0.0 - 2024-02-27

- Initial release.
