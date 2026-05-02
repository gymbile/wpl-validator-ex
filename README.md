# wpl_validator

[![Hex.pm](https://img.shields.io/hexpm/v/wpl_validator.svg)](https://hex.pm/packages/wpl_validator)
[![CI](https://github.com/gymbile/wpl-validator-ex/actions/workflows/ci.yml/badge.svg)](https://github.com/gymbile/wpl-validator-ex/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)

Reference Elixir validator for [WPL (Wellness Plan Language)](https://wpl.dev). Sister
implementation of [`@gymbile/wpl-validator`](https://www.npmjs.com/package/@gymbile/wpl-validator) —
same conformance suite, identical `(code, path)` results.

## Install

```elixir
def deps do
  [
    {:wpl_validator, "~> 1.0"}
  ]
end
```

## Usage

```elixir
{:ok, plan} = Jason.decode(json_string)

result = WPL.Validator.validate(plan)
# %WPL.Validator.Result{
#   valid?: true,
#   errors: []
# }
```

With a catalog (resolves `*_ref` checks):

```elixir
catalog = %{
  exercises: MapSet.new(["push_up", "squat"]),
  meals: MapSet.new(["oatmeal"])
}
WPL.Validator.validate(plan, catalog: catalog)
```

If no catalog is provided, `:unresolved_ref` checks are skipped.

## Conformance

Vendored from [`gymbile/wpl@v1.1.1`](https://github.com/gymbile/wpl/tree/v1.1.1/conformance).
All conformance fixtures pass.

## License

[Apache-2.0](LICENSE).

"WPL" and "Wellness Plan Language" are trademarks of Gymbile.
