defmodule WPL.Enforce do
  @moduledoc """
  Pass-3 enforcement: evaluate personalization rules against a ClientContext
  and strip forbidden activities from a compiled WPL plan.

  Ported from wpl-validator-ts/src/enforce/index.ts. Pure function, no
  process state. Maps are immutable in Elixir so "deep clone" is structural
  copy via `Jason.decode!(Jason.encode!(plan_json))` for round-trip purity,
  matching the TS `JSON.parse(JSON.stringify(...))` behavior.
  """

  alias WPL.Enforce.{Cycle, Matcher, RuleEvaluator}

  @applicable_actions MapSet.new(["forbid_exercise"])

  @type client_context :: map()
  @type rule :: map()
  @type enforce_opts :: [plan_start_date: String.t()]
  @type enforcement_result :: %{
          plan: map(),
          evaluated_rules: [map()],
          stripped: [map()],
          diagnostics: [map()]
        }

  @doc """
  Evaluate `rules` against `ctx` and strip forbidden activities from `plan_json`.

  Returns `%{plan, evaluated_rules, stripped, diagnostics}`.

  Options:
  - `:plan_start_date` — ISO date string of plan day 1 (required for cycle_day-conditioned rules).
  """
  @spec enforce(map(), client_context(), [rule()], enforce_opts()) :: enforcement_result()
  def enforce(plan_json, ctx, rules, opts \\ []) do
    diagnostics = []
    stripped = []

    static_eval = RuleEvaluator.evaluate_rules(rules, ctx)
    diagnostics = diagnostics ++ static_eval.diagnostics

    # Emit diagnostics for non-applicable action types in firing rules
    non_applicable_diags =
      Enum.flat_map(static_eval.evaluated, fn r ->
        Enum.flat_map(r.actions, fn a ->
          type = a["type"] || a[:type] || ""

          if not MapSet.member?(@applicable_actions, type) do
            [
              %{
                code: "UNKNOWN_ACTION_TYPE",
                rule_id: r.rule_id,
                message:
                  "action type '#{type}' has no enforcement applicator yet — it is reported but not applied",
                meta: %{action_type: type}
              }
            ]
          else
            []
          end
        end)
      end)

    diagnostics = diagnostics ++ non_applicable_diags

    static_forbids = forbidden_exercises(tag_actions(static_eval.evaluated))

    # Deep clone via JSON round-trip (matches TS JSON.parse/JSON.stringify)
    clone = plan_json |> Jason.encode!() |> Jason.decode!()
    inner_plan = Map.get(clone, "plan")

    if not is_map(inner_plan) do
      %{
        plan: clone,
        evaluated_rules: static_eval.evaluated,
        stripped: stripped,
        diagnostics: diagnostics
      }
    else
      plan_start_date = Keyword.get(opts, :plan_start_date)

      uses_cycle =
        not is_nil(ctx[:cycle] || Map.get(ctx, "cycle")) and not is_nil(plan_start_date)

      {new_plan, stripped, diagnostics} =
        walk_phases(
          inner_plan,
          ctx,
          rules,
          static_forbids,
          uses_cycle,
          plan_start_date,
          stripped,
          diagnostics
        )

      final_clone = Map.put(clone, "plan", new_plan)

      %{
        plan: final_clone,
        evaluated_rules: static_eval.evaluated,
        stripped: stripped,
        diagnostics: diagnostics
      }
    end
  end

  defp tag_actions(evaluated) do
    Enum.flat_map(evaluated, fn r ->
      if r.condition_met do
        Enum.map(r.actions, fn a -> Map.put(a, "__rule_id", r.rule_id) end)
      else
        []
      end
    end)
  end

  defp forbidden_exercises(actions) do
    Enum.reduce(actions, %{}, fn a, acc ->
      type = a["type"] || a[:type]
      exercise = a["exercise"] || a[:exercise]
      rule_id = a["__rule_id"] || "unknown_rule"

      if type == "forbid_exercise" and is_binary(exercise) and not Map.has_key?(acc, exercise) do
        Map.put(acc, exercise, rule_id)
      else
        acc
      end
    end)
  end

  defp activity_name(act) do
    cond do
      is_binary(act["exercise_ref"]) -> act["exercise_ref"]
      is_binary(act["name"]) -> act["name"]
      true -> ""
    end
  end

  defp match_forbid(name, forbids) do
    if name == "" do
      nil
    else
      Enum.find_value(forbids, fn {pattern, rule_id} ->
        if Matcher.collides(name, pattern), do: rule_id, else: nil
      end)
    end
  end

  defp walk_phases(
         inner_plan,
         ctx,
         rules,
         static_forbids,
         uses_cycle,
         plan_start_date,
         stripped,
         diagnostics
       ) do
    phases = inner_plan["phases"] || []

    {new_phases, stripped, diagnostics, _weeks_before} =
      phases
      |> Enum.with_index()
      |> Enum.reduce(
        {[], stripped, diagnostics, 0},
        fn {phase, _pi}, {acc_phases, acc_stripped, acc_diags, weeks_before} ->
          weeks = phase["weeks"] || []

          {new_weeks, acc_stripped, acc_diags} =
            weeks
            |> Enum.with_index()
            |> Enum.reduce(
              {[], acc_stripped, acc_diags},
              fn {week, wi}, {acc_weeks, acc_s, acc_d} ->
                week_order =
                  if is_number(week["order"]), do: trunc(week["order"]), else: wi + 1

                days = week["days"] || []

                {new_days, acc_s, acc_d} =
                  days
                  |> Enum.with_index()
                  |> Enum.reduce(
                    {[], acc_s, acc_d},
                    fn {day, di}, {acc_days, s, d} ->
                      forbids =
                        if uses_cycle do
                          dow = Cycle.day_of_week_offset(day["day_of_week"])

                          if not is_nil(dow) and not is_nil(plan_start_date) do
                            date =
                              Cycle.day_date_for_plan_position(
                                plan_start_date,
                                weeks_before,
                                week_order,
                                dow
                              )

                            cycle = ctx[:cycle] || Map.get(ctx, "cycle")

                            if is_map(cycle) do
                              cd = Cycle.compute_cycle_day(date, cycle)

                              day_eval =
                                RuleEvaluator.evaluate_rules(rules, Map.put(ctx, :cycle_day, cd))

                              day_forbids = forbidden_exercises(tag_actions(day_eval.evaluated))
                              Map.merge(static_forbids, day_forbids)
                            else
                              static_forbids
                            end
                          else
                            static_forbids
                          end
                        else
                          static_forbids
                        end

                      if map_size(forbids) == 0 do
                        {[day | acc_days], s, d}
                      else
                        blocks = day["blocks"] || []

                        # phase_idx is the 0-based input index; length(acc_phases) equals
                        # the number of phases already processed, which is the same as _pi.
                        phase_idx = length(acc_phases)

                        {new_blocks, s, d} =
                          blocks
                          |> Enum.with_index()
                          |> Enum.reduce(
                            {[], s, d},
                            fn {block, bi}, {acc_blocks, bs, bd} ->
                              activities = block["activities"] || []

                              {kept, bs, bd} =
                                activities
                                |> Enum.with_index()
                                |> Enum.reduce(
                                  {[], bs, bd},
                                  fn {act, ai}, {k, ks, kd} ->
                                    name = activity_name(act)
                                    matched_rule = match_forbid(name, forbids)

                                    if is_nil(matched_rule) do
                                      {[act | k], ks, kd}
                                    else
                                      path =
                                        "/plan/phases/#{phase_idx}/weeks/#{wi}/days/#{di}/blocks/#{bi}/activities/#{ai}"

                                      entry = %{
                                        exercise: name,
                                        matched_rule: matched_rule,
                                        path: path
                                      }

                                      {k, [entry | ks], kd}
                                    end
                                  end
                                )

                              new_block = Map.put(block, "activities", Enum.reverse(kept))
                              {[new_block | acc_blocks], bs, bd}
                            end
                          )

                        new_day = Map.put(day, "blocks", Enum.reverse(new_blocks))
                        {[new_day | acc_days], s, d}
                      end
                    end
                  )

                new_week = Map.put(week, "days", Enum.reverse(new_days))
                {[new_week | acc_weeks], acc_s, acc_d}
              end
            )

          new_phase = Map.put(phase, "weeks", Enum.reverse(new_weeks))

          {[new_phase | acc_phases], acc_stripped, acc_diags, weeks_before + length(weeks)}
        end
      )

    new_inner = Map.put(inner_plan, "phases", Enum.reverse(new_phases))
    {new_inner, Enum.reverse(stripped), diagnostics}
  end
end
