defmodule WPL.Validator.Rule do
  @moduledoc false

  alias WPL.Validator.WalkContext

  @callback enter_plan(WalkContext.t(), map()) :: WalkContext.t()
  @callback enter_phase(WalkContext.t(), map(), String.t()) :: WalkContext.t()
  @callback enter_week(WalkContext.t(), map(), String.t()) :: WalkContext.t()
  @callback enter_day(WalkContext.t(), map(), String.t()) :: WalkContext.t()
  @callback enter_block(WalkContext.t(), map(), String.t()) :: WalkContext.t()
  @callback enter_activity(WalkContext.t(), map(), String.t()) :: WalkContext.t()
  @callback enter_personalization_rule(WalkContext.t(), map(), String.t()) :: WalkContext.t()
  @callback enter_checkpoint(WalkContext.t(), map(), String.t()) :: WalkContext.t()
  @callback enter_points_rule(WalkContext.t(), map(), String.t()) :: WalkContext.t()

  @optional_callbacks enter_plan: 2,
                      enter_phase: 3,
                      enter_week: 3,
                      enter_day: 3,
                      enter_block: 3,
                      enter_activity: 3,
                      enter_personalization_rule: 3,
                      enter_checkpoint: 3,
                      enter_points_rule: 3

  defmacro __using__(_) do
    quote do
      @behaviour WPL.Validator.Rule

      def enter_plan(ctx, _plan), do: ctx
      def enter_phase(ctx, _phase, _path), do: ctx
      def enter_week(ctx, _week, _path), do: ctx
      def enter_day(ctx, _day, _path), do: ctx
      def enter_block(ctx, _block, _path), do: ctx
      def enter_activity(ctx, _activity, _path), do: ctx
      def enter_personalization_rule(ctx, _rule, _path), do: ctx
      def enter_checkpoint(ctx, _cp, _path), do: ctx
      def enter_points_rule(ctx, _rule, _path), do: ctx

      defoverridable WPL.Validator.Rule
    end
  end
end
