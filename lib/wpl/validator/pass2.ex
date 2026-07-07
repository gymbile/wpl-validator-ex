defmodule WPL.Validator.Pass2 do
  @moduledoc false

  alias WPL.Validator.WalkContext

  alias WPL.Validator.Rules.{
    ActivityBlockMismatch,
    CyclicSubplan,
    DietaryTagsOffVocab,
    DuplicateId,
    EmptyPhasesForType,
    GoalCategoryOffVocab,
    InvalidPersonalizationRule,
    InvalidPointsRule,
    InvalidPrescription,
    PhaseDurationMismatch,
    UnresolvedRef
  }

  @rules [
    ActivityBlockMismatch,
    CyclicSubplan,
    DietaryTagsOffVocab,
    DuplicateId,
    EmptyPhasesForType,
    GoalCategoryOffVocab,
    InvalidPersonalizationRule,
    InvalidPointsRule,
    InvalidPrescription,
    PhaseDurationMismatch,
    UnresolvedRef
  ]

  @spec run(any(), keyword()) :: [WPL.Validator.Error.t()]
  def run(input, opts) do
    ctx = %WalkContext{opts: opts}
    plan = get_plan(input)

    if is_map(plan) do
      ctx
      |> walk_plan(plan)
      |> Map.fetch!(:errors)
      |> Enum.reverse()
    else
      []
    end
  end

  defp get_plan(%{"plan" => plan}), do: plan
  defp get_plan(_), do: nil

  defp walk_plan(ctx, plan) do
    ctx = Enum.reduce(@rules, ctx, fn rule, c -> rule.enter_plan(c, plan) end)

    phases = plan |> Map.get("phases", []) |> List.wrap()

    ctx =
      phases
      |> Enum.with_index()
      |> Enum.reduce(ctx, fn {phase, pi}, c ->
        walk_phase(c, phase, "/plan/phases/#{pi}")
      end)

    ctx
    |> walk_personalization(plan)
    |> walk_progress(plan)
  end

  defp walk_phase(ctx, phase, phase_path) when is_map(phase) do
    ctx = WalkContext.put_scope(ctx, :cur_phase, Map.get(phase, "id"))
    ctx = Enum.reduce(@rules, ctx, fn rule, c -> rule.enter_phase(c, phase, phase_path) end)

    weeks = phase |> Map.get("weeks", []) |> List.wrap()

    weeks
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {week, wi}, c ->
      walk_week(c, week, "#{phase_path}/weeks/#{wi}")
    end)
  end

  defp walk_phase(ctx, _phase, _path), do: ctx

  defp walk_week(ctx, week, week_path) when is_map(week) do
    ctx = WalkContext.put_scope(ctx, :cur_week, Map.get(week, "id"))
    ctx = Enum.reduce(@rules, ctx, fn rule, c -> rule.enter_week(c, week, week_path) end)

    days = week |> Map.get("days", []) |> List.wrap()

    days
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {day, di}, c ->
      walk_day(c, day, "#{week_path}/days/#{di}")
    end)
  end

  defp walk_week(ctx, _week, _path), do: ctx

  defp walk_day(ctx, day, day_path) when is_map(day) do
    ctx = WalkContext.put_scope(ctx, :cur_day, Map.get(day, "id"))
    ctx = Enum.reduce(@rules, ctx, fn rule, c -> rule.enter_day(c, day, day_path) end)

    blocks = day |> Map.get("blocks", []) |> List.wrap()

    blocks
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {block, bi}, c ->
      walk_block(c, block, "#{day_path}/blocks/#{bi}")
    end)
  end

  defp walk_day(ctx, _day, _path), do: ctx

  defp walk_block(ctx, block, block_path) when is_map(block) do
    ctx = Enum.reduce(@rules, ctx, fn rule, c -> rule.enter_block(c, block, block_path) end)

    activities = block |> Map.get("activities", []) |> List.wrap()

    activities
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {activity, ai}, c ->
      walk_activity(c, activity, "#{block_path}/activities/#{ai}")
    end)
  end

  defp walk_block(ctx, _block, _path), do: ctx

  defp walk_activity(ctx, activity, activity_path) when is_map(activity) do
    Enum.reduce(@rules, ctx, fn rule, c -> rule.enter_activity(c, activity, activity_path) end)
  end

  defp walk_activity(ctx, _activity, _path), do: ctx

  defp walk_personalization(ctx, plan) do
    rules_list =
      plan
      |> Map.get("personalization", %{})
      |> then(fn
        v when is_map(v) -> Map.get(v, "rules", [])
        _ -> []
      end)
      |> List.wrap()

    rules_list
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {rule, ri}, c ->
      if is_map(rule) do
        path = "/plan/personalization/rules/#{ri}"

        Enum.reduce(@rules, c, fn mod, acc ->
          mod.enter_personalization_rule(acc, rule, path)
        end)
      else
        c
      end
    end)
  end

  defp walk_progress(ctx, plan) do
    progress = Map.get(plan, "progress")

    ctx = walk_checkpoints(ctx, progress)
    walk_points_rules(ctx, progress)
  end

  defp walk_checkpoints(ctx, progress) when is_map(progress) do
    checkpoints = progress |> Map.get("checkpoints", []) |> List.wrap()

    checkpoints
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {cp, ci}, c ->
      if is_map(cp) do
        path = "/plan/progress/checkpoints/#{ci}"
        Enum.reduce(@rules, c, fn mod, acc -> mod.enter_checkpoint(acc, cp, path) end)
      else
        c
      end
    end)
  end

  defp walk_checkpoints(ctx, _), do: ctx

  defp walk_points_rules(ctx, progress) when is_map(progress) do
    points_rules =
      progress
      |> Map.get("points_system", %{})
      |> then(fn
        v when is_map(v) -> Map.get(v, "rules", [])
        _ -> []
      end)
      |> List.wrap()

    points_rules
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {rule, ri}, c ->
      if is_map(rule) do
        path = "/plan/progress/points_system/rules/#{ri}"
        Enum.reduce(@rules, c, fn mod, acc -> mod.enter_points_rule(acc, rule, path) end)
      else
        c
      end
    end)
  end

  defp walk_points_rules(ctx, _), do: ctx
end
