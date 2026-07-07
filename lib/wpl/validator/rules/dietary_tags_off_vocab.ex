defmodule WPL.Validator.Rules.DietaryTagsOffVocab do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Data.DietaryTags
  alias WPL.Validator.{Error, WalkContext}

  @impl true
  def enter_activity(ctx, %{"type" => "nutrition"} = activity, path) do
    tags = activity |> Map.get("dietary_tags", []) |> List.wrap()

    Enum.reduce(tags, ctx, fn tag, acc ->
      if is_binary(tag) and tag not in DietaryTags.ids() do
        WalkContext.emit(acc, %Error{
          path: path,
          code: :dietary_tags_off_vocab,
          message: "Dietary tag #{inspect(tag)} is not in the recommended vocabulary",
          severity: :warning,
          meta: %{tag: tag}
        })
      else
        acc
      end
    end)
  end

  def enter_activity(ctx, _activity, _path), do: ctx
end
