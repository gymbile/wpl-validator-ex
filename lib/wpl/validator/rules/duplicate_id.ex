defmodule WPL.Validator.Rules.DuplicateId do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  # -----------------------------------------------------------------------
  # Scope key conventions (stored in WalkContext.scope):
  #   :cur_phase / :cur_week / :cur_day — IDs set by the walker
  #   {:dup_seen, scope_key} — map of id -> first_occurrence_path
  # -----------------------------------------------------------------------

  @impl true
  def enter_plan(ctx, _plan) do
    # Reset all duplicate-id tracking at top of each plan walk.
    new_scope =
      ctx.scope
      |> Enum.reject(fn {k, _} -> match?({:dup_seen, _}, k) end)
      |> Map.new()

    %{ctx | scope: new_scope}
  end

  @impl true
  def enter_phase(ctx, phase, path) do
    check(ctx, {:dup_seen, "plan"}, "plan", Map.get(phase, "id"), path)
  end

  @impl true
  def enter_week(ctx, week, path) do
    phase_id = WalkContext.get_scope(ctx, :cur_phase, "")
    check(ctx, {:dup_seen, "phase:#{phase_id}"}, "phase:#{phase_id}", Map.get(week, "id"), path)
  end

  @impl true
  def enter_day(ctx, day, path) do
    week_id = WalkContext.get_scope(ctx, :cur_week, "")
    check(ctx, {:dup_seen, "week:#{week_id}"}, "week:#{week_id}", Map.get(day, "id"), path)
  end

  @impl true
  def enter_block(ctx, block, path) do
    # Day IDs (`day_1`, `day_2`, ...) are positional within their week and
    # therefore repeat across weeks. Scope block uniqueness to
    # (phase, week, day) so structurally-correct multi-week plans do not
    # falsely report `:duplicate_id` for the same block ID (e.g.
    # `warmup_block`) appearing once per day across weeks.
    day_id = WalkContext.get_scope(ctx, :cur_day, "")
    scope_key = scope_key_for("block", ctx)
    check(ctx, scope_key, "day:#{day_id}", Map.get(block, "id"), path)
  end

  @impl true
  def enter_activity(ctx, activity, path) do
    day_id = WalkContext.get_scope(ctx, :cur_day, "")
    scope_key = scope_key_for("activity", ctx)
    check(ctx, scope_key, "day:#{day_id}", Map.get(activity, "id"), path)
  end

  defp scope_key_for(kind, ctx) do
    phase_id = WalkContext.get_scope(ctx, :cur_phase, "")
    week_id = WalkContext.get_scope(ctx, :cur_week, "")
    day_id = WalkContext.get_scope(ctx, :cur_day, "")
    {:dup_seen, "#{kind}:#{phase_id}:#{week_id}:#{day_id}"}
  end

  # -----------------------------------------------------------------------
  # Private helpers
  # -----------------------------------------------------------------------

  defp check(ctx, scope_key, scope_label, id, path) when is_binary(id) and id != "" do
    seen = WalkContext.get_scope(ctx, scope_key, %{})

    case Map.get(seen, id) do
      nil ->
        WalkContext.put_scope(ctx, scope_key, Map.put(seen, id, path))

      first_path ->
        WalkContext.emit(ctx, %Error{
          path: path,
          code: :duplicate_id,
          message: "Duplicate id '#{id}' within scope #{scope_label}",
          severity: :error,
          meta: %{
            duplicate_id: id,
            scope: scope_label,
            first_occurrence: first_path
          }
        })
    end
  end

  defp check(ctx, _scope_key, _scope_label, _id, _path), do: ctx
end
