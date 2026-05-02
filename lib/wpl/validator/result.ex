defmodule WPL.Validator.Result do
  @moduledoc """
  Outcome of `WPL.Validator.validate/2`.

  Fields:
    * `:valid?` — true iff no error-severity findings.
    * `:errors` — list of `WPL.Validator.Error.t()`. May contain warning-severity entries even when `valid?` is true.
  """

  @type t :: %__MODULE__{
          valid?: boolean(),
          errors: [WPL.Validator.Error.t()]
        }

  @enforce_keys [:valid?, :errors]
  defstruct [:valid?, :errors]
end
