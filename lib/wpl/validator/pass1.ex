defmodule WPL.Validator.Pass1 do
  @moduledoc """
  Pass 1: JSON Schema validation against the canonical WPL v1 schema.

  Loads and resolves the schema at compile time. Uses `ex_json_schema` v0.11,
  which supports Draft 4/6/7. The schema is Draft 2020-12, so we replace
  the `$schema` declaration with the Draft 7 URI at load time — the structural
  keywords used in the WPL schema (`$defs`, `oneOf`, `if/then/else`,
  `additionalProperties`, `enum`, `required`) are all supported under Draft 7.
  """

  alias ExJsonSchema.Validator.Error, as: SchemaError
  alias WPL.Validator.Error

  @schema_path Application.app_dir(:wpl_validator, "priv/schema/v1.schema.json")
  @external_resource @schema_path

  # Load and resolve the schema once at compile time.
  # Replace the $schema declaration with the Draft 7 URI so ex_json_schema accepts it.
  # The WPL v1 schema uses only Draft 7-compatible keywords.
  @raw_schema @schema_path
              |> File.read!()
              |> Jason.decode!()
              |> Map.put("$schema", "http://json-schema.org/draft-07/schema#")

  @resolved_schema ExJsonSchema.Schema.resolve(@raw_schema)

  @spec run(any()) :: [Error.t()]
  def run(input) do
    case ExJsonSchema.Validator.validate(@resolved_schema, input, error_formatter: false) do
      :ok ->
        []

      {:error, errors} ->
        Enum.map(errors, &to_validation_error/1)
    end
  end

  # ex_json_schema returns structured %ExJsonSchema.Validator.Error{error: sub_error, path: path}
  # when error_formatter: false. The path is of the form "#/plan/type"; strip the leading "#"
  # to produce a valid RFC 6901 JSON Pointer (e.g. "/plan/type") or "" for the root.
  defp to_validation_error(%SchemaError{error: sub_error, path: path}) do
    json_pointer = String.replace_prefix(path, "#", "")

    %Error{
      path: json_pointer,
      code: :schema_violation,
      message: to_string(sub_error),
      severity: :error,
      meta: %{keyword: keyword_for(sub_error)}
    }
  end

  # Map structured error sub-types to JSON Schema keyword names, matching
  # the TS validator's ajv `keyword` field for conformance parity.
  defp keyword_for(%SchemaError.AdditionalItems{}), do: "additionalItems"
  defp keyword_for(%SchemaError.AdditionalProperties{}), do: "additionalProperties"
  defp keyword_for(%SchemaError.AllOf{}), do: "allOf"
  defp keyword_for(%SchemaError.AnyOf{}), do: "anyOf"
  defp keyword_for(%SchemaError.Const{}), do: "const"
  defp keyword_for(%SchemaError.Contains{}), do: "contains"
  defp keyword_for(%SchemaError.Dependencies{}), do: "dependencies"
  defp keyword_for(%SchemaError.Enum{}), do: "enum"
  defp keyword_for(%SchemaError.Format{}), do: "format"
  defp keyword_for(%SchemaError.IfThenElse{}), do: "if"
  defp keyword_for(%SchemaError.MaxItems{}), do: "maxItems"
  defp keyword_for(%SchemaError.MaxLength{}), do: "maxLength"
  defp keyword_for(%SchemaError.MaxProperties{}), do: "maxProperties"
  defp keyword_for(%SchemaError.Maximum{}), do: "maximum"
  defp keyword_for(%SchemaError.MinItems{}), do: "minItems"
  defp keyword_for(%SchemaError.MinLength{}), do: "minLength"
  defp keyword_for(%SchemaError.MinProperties{}), do: "minProperties"
  defp keyword_for(%SchemaError.Minimum{}), do: "minimum"
  defp keyword_for(%SchemaError.MultipleOf{}), do: "multipleOf"
  defp keyword_for(%SchemaError.Not{}), do: "not"
  defp keyword_for(%SchemaError.OneOf{}), do: "oneOf"
  defp keyword_for(%SchemaError.Pattern{}), do: "pattern"
  defp keyword_for(%SchemaError.PropertyNames{}), do: "propertyNames"
  defp keyword_for(%SchemaError.Required{}), do: "required"
  defp keyword_for(%SchemaError.Type{}), do: "type"
  defp keyword_for(%SchemaError.UniqueItems{}), do: "uniqueItems"
  defp keyword_for(_), do: nil
end
