defmodule WPL.Enforce.ConformanceTest do
  use ExUnit.Case, async: false

  alias WPL.Enforce

  @enforcement_dir Application.app_dir(:wpl_validator, "priv/enforcement")

  # Each fixture JSON has:
  #   "plan"    — the compiled WPL JSON
  #   "context" — ClientContext (string-keyed; we convert to atom-keyed)
  #   "rules"   — list of personalization rules
  #   "options" — { "planStartDate"?: string }
  #   "expect"  — { "stripped_exercises": [...], "surviving_refs": [...], "diagnostic_codes": [...] }

  describe "enforcement conformance fixtures" do
    for path <- Path.wildcard(Path.join(@enforcement_dir, "*.json")) do
      @path path
      test Path.basename(@path, ".json") do
        fixture = @path |> File.read!() |> Jason.decode!()

        plan = fixture["plan"]
        ctx = atomize_context(fixture["context"] || %{})
        rules = fixture["rules"] || []
        opts = build_opts(fixture["options"] || %{})
        expect = fixture["expect"]

        result = Enforce.enforce(plan, ctx, rules, opts)

        # stripped_exercises: every exercise listed must appear in result.stripped
        stripped_names = Enum.map(result.stripped, & &1.exercise)

        for ex <- expect["stripped_exercises"] || [] do
          assert ex in stripped_names,
                 "Expected '#{ex}' to be stripped, but stripped was: #{inspect(stripped_names)}"
        end

        # No extra strips beyond what is expected
        assert length(result.stripped) == length(expect["stripped_exercises"] || []),
               "Expected #{length(expect["stripped_exercises"] || [])} stripped, got #{length(result.stripped)}: #{inspect(stripped_names)}"

        # surviving_refs: these exercise_refs must appear in the output plan
        all_activity_refs = collect_all_refs(result.plan)

        for ref <- expect["surviving_refs"] || [] do
          assert ref in all_activity_refs,
                 "Expected '#{ref}' to survive, but activities were: #{inspect(all_activity_refs)}"
        end

        # diagnostic_codes: expected codes must appear in diagnostics
        diag_codes = Enum.map(result.diagnostics, & &1.code)

        for code <- expect["diagnostic_codes"] || [] do
          assert code in diag_codes,
                 "Expected diagnostic '#{code}', got: #{inspect(diag_codes)}"
        end
      end
    end
  end

  # Convert string-keyed context map to atom-keyed, and handle nested cycle map.
  defp atomize_context(ctx) when is_map(ctx) do
    ctx
    |> Enum.map(fn
      {"cycle", v} when is_map(v) -> {:cycle, atomize_context(v)}
      {k, v} -> {String.to_atom(k), v}
    end)
    |> Map.new()
  end

  defp build_opts(options) when is_map(options) do
    case Map.get(options, "planStartDate") do
      nil -> []
      date -> [plan_start_date: date]
    end
  end

  # Walk the output plan and collect all exercise_ref and name strings.
  defp collect_all_refs(plan) when is_map(plan) do
    (plan["plan"]["phases"] || [])
    |> Enum.flat_map(fn phase ->
      (phase["weeks"] || [])
      |> Enum.flat_map(fn week ->
        (week["days"] || [])
        |> Enum.flat_map(fn day ->
          (day["blocks"] || [])
          |> Enum.flat_map(fn block ->
            (block["activities"] || [])
            |> Enum.flat_map(fn act ->
              [act["exercise_ref"], act["name"]]
              |> Enum.filter(&is_binary/1)
            end)
          end)
        end)
      end)
    end)
  end
end
