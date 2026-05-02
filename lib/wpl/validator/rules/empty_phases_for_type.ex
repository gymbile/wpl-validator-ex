defmodule WPL.Validator.Rules.EmptyPhasesForType do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  @types_requiring_phases MapSet.new(["workout", "hybrid"])

  @impl true
  def enter_plan(ctx, plan) do
    plan_type = Map.get(plan, "type")

    if is_binary(plan_type) and MapSet.member?(@types_requiring_phases, plan_type) do
      phases = plan |> Map.get("phases", []) |> List.wrap()

      if phases == [] do
        WalkContext.emit(ctx, %Error{
          path: "/plan/phases",
          code: :empty_phases_for_type,
          message: "Plan type '#{plan_type}' requires at least one phase",
          severity: :error,
          meta: %{plan_type: plan_type}
        })
      else
        ctx
      end
    else
      ctx
    end
  end
end
