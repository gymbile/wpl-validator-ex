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
        Enum.flat_map(errors, &expand_to_validation_errors/1)
    end
  end

  # OneOf: drill into the branch(es) that "best match" (fewest inner errors),
  # surfacing specific errors rather than a bare oneOf failure at the parent.
  # Matches ajv's behavior with discriminated unions for cross-validator parity.
  #
  # Tie-breaking: when multiple branches share the minimum error count, emit
  # errors from ALL tied branches. This ensures any of the tied branches'
  # errors can satisfy a `SCHEMA_VIOLATION` conformance expectation regardless
  # of which branch ajv vs ex_json_schema picks first.
  #
  # Nested-OneOf stop: if the sole best-match branch contains a single error
  # that is itself a OneOf, report `additionalProperties` at that nested
  # OneOf's path rather than recursing. ajv surfaces the parent-level failure
  # for mismatched discriminated sub-schemas rather than drilling into the
  # nested oneOf.
  defp expand_to_validation_errors(%SchemaError{error: %SchemaError.OneOf{invalid: invalid}})
       when is_list(invalid) and invalid != [] do
    min_count =
      invalid
      |> Enum.map(fn %{errors: errs} -> length(errs) end)
      |> Enum.min()

    best_branches =
      Enum.filter(invalid, fn %{errors: errs} -> length(errs) == min_count end)

    case best_branches do
      [single_branch] ->
        case single_branch.errors do
          [%SchemaError{error: %SchemaError.OneOf{}, path: nested_path}] ->
            # Nested oneOf failure: report additionalProperties at the nested
            # path (ajv coerces this to an additionalProperties-level report).
            json_pointer = String.replace_prefix(nested_path, "#", "")

            [
              %Error{
                path: json_pointer,
                code: :schema_violation,
                message: "Value does not match any allowed schema variant.",
                severity: :error,
                meta: %{keyword: "additionalProperties"}
              }
            ]

          errors ->
            Enum.flat_map(errors, &expand_to_validation_errors/1)
        end

      multiple_branches ->
        # Tie: emit errors from all tied branches so the conformance check
        # can match against whichever branch the expected fixture targets.
        Enum.flat_map(multiple_branches, fn %{errors: errs} ->
          Enum.flat_map(errs, &expand_to_validation_errors/1)
        end)
    end
  end

  defp expand_to_validation_errors(%SchemaError{} = err), do: [to_validation_error(err)]

  # ex_json_schema returns structured %ExJsonSchema.Validator.Error{error: sub_error, path: path}
  # when error_formatter: false. The path is of the form "#/plan/type"; strip the leading "#"
  # to produce a valid RFC 6901 JSON Pointer (e.g. "/plan/type") or "" for the root.
  #
  # AdditionalProperties is special-cased for cross-validator parity: ex_json_schema
  # reports the path of the offending property (`/plan/secret_field`), but the
  # WPL conformance contract requires the parent path (`/plan`) with the offending
  # property name carried in `meta.params.additional_property`, matching ajv's
  # `instancePath` + `params` shape.
  defp to_validation_error(%SchemaError{
         error: %SchemaError.AdditionalProperties{} = sub_error,
         path: path
       }) do
    json_pointer = String.replace_prefix(path, "#", "")
    {parent, prop} = split_last_pointer_segment(json_pointer)

    %Error{
      path: parent,
      code: :schema_violation,
      message: to_string(sub_error),
      severity: :error,
      meta: %{
        keyword: "additionalProperties",
        params: %{additional_property: prop}
      }
    }
  end

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

  # Split "/plan/secret_field" → {"/plan", "secret_field"}. Root path "" stays {"", ""}.
  defp split_last_pointer_segment(""), do: {"", ""}

  defp split_last_pointer_segment(pointer) do
    case String.split(pointer, "/") do
      ["", _ | _] = parts ->
        {last, leading} = List.pop_at(parts, -1)
        {Enum.join(leading, "/"), last}

      _ ->
        {pointer, ""}
    end
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
