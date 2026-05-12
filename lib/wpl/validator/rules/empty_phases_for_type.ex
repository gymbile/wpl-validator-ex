defmodule WPL.Validator.Rules.EmptyPhasesForType do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, RepairHint, WalkContext}

  @types_requiring_phases MapSet.new(["workout", "hybrid"])

  @dsl_phase_example """
  PHASES
    PHASE "Phase 1: Foundation" (4 weeks):
      WEEK 1:
        DAY Monday training 45m "Session name":
          warmup:
            cycling 5m zone2
          main straight_sets:
            <exercise_name> 3x8..12 rpe 7 rest 90 seconds
          cooldown:
            <stretch_name> 30s\
  """

  @impl true
  def enter_plan(ctx, plan) do
    plan_type = Map.get(plan, "type")

    if is_binary(plan_type) and MapSet.member?(@types_requiring_phases, plan_type) do
      phases = plan |> Map.get("phases", []) |> List.wrap()

      if phases == [] do
        repair_hint = %RepairHint{
          action: :add_phases,
          target_path: "/plan/phases",
          expected_count: 1,
          actual_count: 0,
          expected_shape:
            "plan.phases must be a non-empty array of Phase objects for plan.type='#{plan_type}'",
          context_dsl_example: @dsl_phase_example
        }

        WalkContext.emit(ctx, %Error{
          path: "/plan/phases",
          code: :empty_phases_for_type,
          message: "Plan type '#{plan_type}' requires at least one phase",
          severity: :error,
          meta: %{plan_type: plan_type},
          repair_hint: repair_hint
        })
      else
        ctx
      end
    else
      ctx
    end
  end
end
