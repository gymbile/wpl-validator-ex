# WPL Validator — Livebooks

Interactive notebooks for exploring WPL plans with the Elixir validator.
Open any of these in [Livebook](https://livebook.dev) (`livebook server`),
then `Open from file` and pick the `.livemd`.

| Notebook | Topic |
|---|---|
| [`01_quickstart.livemd`](01_quickstart.livemd) | Paste a plan, validate, render findings |
| [`02_authoring_a_program.livemd`](02_authoring_a_program.livemd) | Build a 5/3/1 cycle programmatically and serialize |
| [`03_diagnosing_errors.livemd`](03_diagnosing_errors.livemd) | Tour every error code with bad → good fixes |
| [`04_analytics.livemd`](04_analytics.livemd) | Compute weekly volume / intensity, render with Vega-Lite |

Each notebook installs `wpl_validator` from the local repo via
`Mix.install([{:wpl_validator, path: Path.join(__DIR__, "..")}])`, so they
work without publishing the package — just clone, open, and run.
