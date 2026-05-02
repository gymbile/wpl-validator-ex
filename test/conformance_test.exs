defmodule WPL.ConformanceTest do
  use ExUnit.Case, async: false

  alias WPL.Validator
  alias WPL.Validator.Error

  @conformance_dir Application.app_dir(:wpl_validator, "priv/conformance")

  # ---------------------------------------------------------------------------
  # Valid fixtures
  # ---------------------------------------------------------------------------

  describe "valid fixtures" do
    for path <- Path.wildcard(Path.join(@conformance_dir, "valid/*.json")) do
      @path path
      test "valid/#{Path.basename(@path)}: validates with no errors" do
        plan = read_json!(@path)
        result = Validator.validate(plan)
        assert result.valid? == true, "Expected valid, got errors: #{inspect(result.errors)}"
        assert result.errors == []
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Invalid fixtures
  # ---------------------------------------------------------------------------

  describe "invalid fixtures" do
    for path <-
          Path.wildcard(Path.join(@conformance_dir, "invalid/*.json")),
        not String.ends_with?(path, ".expected.json"),
        not String.ends_with?(path, ".catalog.json") do
      @path path
      test "invalid/#{Path.basename(@path)}: emits expected errors" do
        base = String.replace_suffix(@path, ".json", "")
        plan = read_json!(@path)
        expected_errors = read_json!(base <> ".expected.json")

        opts =
          if File.exists?(base <> ".catalog.json") do
            catalog_data = read_json!(base <> ".catalog.json")

            catalog =
              catalog_data
              |> Enum.map(fn {k, v} -> {String.to_atom(k), MapSet.new(v)} end)
              |> Map.new()

            [catalog: catalog]
          else
            []
          end

        result = Validator.validate(plan, opts)

        assert errors_match?(result, expected_errors),
               describe_mismatch(result, expected_errors)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp read_json!(path), do: path |> File.read!() |> Jason.decode!()

  # All expected errors appear in actuals (by code+path+severity+meta subset),
  # and no extra errors exist beyond expected — unless expected includes a
  # SCHEMA_VIOLATION (where extra cascade violations are permitted).
  defp errors_match?(result, expected_errors) do
    all_expected_present =
      Enum.all?(expected_errors, fn exp ->
        Enum.any?(result.errors, &error_matches?(&1, exp))
      end)

    count_ok = error_count_within_bounds?(result.errors, expected_errors)

    all_expected_present and count_ok
  end

  defp error_matches?(%Error{} = actual, expected) do
    expected_code = code_string_to_atom(expected["code"])
    expected_severity = String.to_atom(expected["severity"])

    actual.code == expected_code and
      actual.path == expected["path"] and
      actual.severity == expected_severity and
      meta_subset_matches?(actual.meta, expected["meta"])
  end

  # Every key in expected_meta must be present in actual.meta with a matching
  # value. Actual may have additional keys (subset match).
  #
  # Key normalisation: expected JSON has string keys; actual.meta has atom keys.
  # Try atom key first, fall back to string key.
  #
  # Value normalisation: some meta values are atoms in Elixir (e.g. `reason:
  # :sets_reps_requires_sets_or_reps`) but strings in the expected JSON.
  # Normalise by converting actual values to strings when the expected value is
  # a string and the actual value is an atom.
  defp meta_subset_matches?(_actual, nil), do: true
  defp meta_subset_matches?(_actual, expected_meta) when expected_meta == %{}, do: true

  defp meta_subset_matches?(actual, expected_meta) when is_map(expected_meta) do
    Enum.all?(expected_meta, fn {exp_key_str, exp_value} ->
      atom_key = String.to_atom(exp_key_str)
      actual_value = Map.get(actual, atom_key, Map.get(actual, exp_key_str))
      values_match?(actual_value, exp_value)
    end)
  end

  defp meta_subset_matches?(_actual, _expected_meta), do: false

  # Atom values (e.g. `:sets_reps_requires_sets_or_reps`) match string expected
  # values (e.g. `"sets_reps_requires_sets_or_reps"`) via Atom.to_string/1.
  defp values_match?(actual, expected) when is_atom(actual) and is_binary(expected) do
    Atom.to_string(actual) == expected
  end

  defp values_match?(actual, expected), do: actual == expected

  # If SCHEMA_VIOLATION appears in expected, allow extra violations (ajv/
  # ex_json_schema cascade). Otherwise require exact count.
  defp error_count_within_bounds?(actual_errors, expected_errors) do
    if Enum.any?(expected_errors, &(&1["code"] == "SCHEMA_VIOLATION")) do
      true
    else
      length(actual_errors) == length(expected_errors)
    end
  end

  defp code_string_to_atom("SCHEMA_VIOLATION"), do: :schema_violation
  defp code_string_to_atom("DUPLICATE_ID"), do: :duplicate_id
  defp code_string_to_atom("UNRESOLVED_REF"), do: :unresolved_ref
  defp code_string_to_atom("EMPTY_PHASES_FOR_TYPE"), do: :empty_phases_for_type
  defp code_string_to_atom("INVALID_PRESCRIPTION"), do: :invalid_prescription
  defp code_string_to_atom("INVALID_PERSONALIZATION_RULE"), do: :invalid_personalization_rule
  defp code_string_to_atom("INVALID_POINTS_RULE"), do: :invalid_points_rule
  defp code_string_to_atom("PHASE_DURATION_MISMATCH"), do: :phase_duration_mismatch

  defp describe_mismatch(result, expected_errors) do
    """
    Actual errors:
    #{Enum.map_join(result.errors, "\n", &"  #{inspect(&1)}")}

    Expected errors:
    #{Enum.map_join(expected_errors, "\n", &"  #{inspect(&1)}")}
    """
  end
end
