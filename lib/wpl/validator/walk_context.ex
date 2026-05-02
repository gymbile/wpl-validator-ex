defmodule WPL.Validator.WalkContext do
  @moduledoc false

  alias WPL.Validator.Error

  @type t :: %__MODULE__{
          opts: keyword(),
          errors: [Error.t()],
          scope: map()
        }

  defstruct opts: [], errors: [], scope: %{}

  @doc "Append an error to the context."
  @spec emit(t(), Error.t()) :: t()
  def emit(%__MODULE__{errors: errors} = ctx, %Error{} = err) do
    %__MODULE__{ctx | errors: [err | errors]}
  end

  @doc "Store a value in scope under the given key."
  @spec put_scope(t(), atom() | String.t(), term()) :: t()
  def put_scope(%__MODULE__{scope: scope} = ctx, key, value) do
    %__MODULE__{ctx | scope: Map.put(scope, key, value)}
  end

  @doc "Retrieve a value from scope, returning `default` (nil) when absent."
  @spec get_scope(t(), atom() | String.t(), term()) :: term()
  def get_scope(%__MODULE__{scope: scope}, key, default \\ nil) do
    Map.get(scope, key, default)
  end
end
