defmodule WPL.Validator.Rules.CyclicSubplan do
  @moduledoc """
  Detects sub-plan reference cycles.

  Single-plan scope: catches self-references where a `SubPlanActivity`
  has `sub_plan_ref` equal to the containing plan's `id`. Cross-plan
  cycles (`A → B → A`) require a `sub_plans` resolution map at validate
  time and are deferred until that API extension lands.
  """
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  @impl true
  def enter_plan(ctx, plan) do
    case Map.get(plan, "id") do
      id when is_binary(id) and id != "" ->
        WalkContext.put_scope(ctx, :cur_plan_id, id)

      _ ->
        ctx
    end
  end

  @impl true
  def enter_activity(ctx, activity, path) do
    with "sub_plan" <- Map.get(activity, "type"),
         ref when is_binary(ref) and ref != "" <- Map.get(activity, "sub_plan_ref"),
         plan_id when is_binary(plan_id) <-
           WalkContext.get_scope(ctx, :cur_plan_id, nil),
         true <- ref == plan_id do
      WalkContext.emit(ctx, %Error{
        path: path,
        code: :cyclic_subplan,
        message: "Sub-plan reference '#{ref}' creates a self-cycle",
        severity: :error,
        meta: %{cycle: [plan_id, ref]}
      })
    else
      _ -> ctx
    end
  end
end
