defmodule WPL.Validator.Rules.ActivityBlockMismatch do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, RepairHint, WalkContext}

  @allowed %{
    "warmup" => ~w(exercise cardio recovery simple sub_plan),
    "main" => ~w(exercise cardio nutrition meditation recovery habit simple sub_plan),
    "cooldown" => ~w(exercise cardio recovery meditation simple sub_plan),
    "nutrition" => ~w(nutrition simple sub_plan),
    "meditation" => ~w(meditation simple sub_plan),
    "education" => ~w(simple habit sub_plan),
    "assessment" => ~w(exercise cardio simple sub_plan)
  }

  @impl true
  def enter_block(ctx, block, _path) do
    block_type = Map.get(block, "type")
    WalkContext.put_scope(ctx, :cur_block_type, block_type)
  end

  @impl true
  def enter_activity(ctx, activity, path) do
    block_type = WalkContext.get_scope(ctx, :cur_block_type)

    with true <- is_binary(block_type),
         {:ok, allowed} <- Map.fetch(@allowed, block_type),
         act_type when is_binary(act_type) <- Map.get(activity, "type"),
         false <- act_type in allowed do
      allowed_str = Enum.join(allowed, ", ")
      activity_name = Map.get(activity, "name")

      repair_hint = %RepairHint{
        action: :fix_activity,
        target_path: path,
        parent_name: if(is_binary(activity_name), do: activity_name, else: nil),
        allowed_values: allowed,
        expected_shape: "activity.type must be one of: #{allowed_str} (block type: #{block_type})"
      }

      WalkContext.emit(ctx, %Error{
        path: path,
        code: :activity_block_mismatch,
        message:
          "Activity type '#{act_type}' not allowed in '#{block_type}' block. Allowed: #{allowed_str}.",
        severity: :error,
        meta: %{
          activity_type: act_type,
          block_type: block_type,
          allowed: allowed
        },
        repair_hint: repair_hint
      })
    else
      _ -> ctx
    end
  end
end
