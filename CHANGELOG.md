# Changelog

## v3.0.0 - Unreleased

- The API has been redesigned to take advantage of Gleam's `use` and the
  pattern that `gleam/dynamic/decode` uses.

## v2.2.0 - 2024-08-26

- Updated for `gleam_stdlib` v0.40.0.

## v2.1.0 - 2024-08-20

- Added the `must_be_string_shorter_than` function.
- Fixed a bug in the `must_be_string_longer_than` error message.

## v2.0.0 - 2024-06-24

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
