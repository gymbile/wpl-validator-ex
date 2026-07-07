defmodule WPL.Data.DietaryTagsCodegenTest do
  use ExUnit.Case, async: true

  alias WPL.Data.DietaryTags

  @root File.cwd!()

  test "exposes all dietary-tag ids from the vendored JSON" do
    json =
      Path.join(@root, "priv/data/dietary-tags.json")
      |> File.read!()
      |> Jason.decode!()

    expected_ids = Enum.map(json["tags"], & &1["id"])
    assert DietaryTags.ids() == expected_ids
  end

  test "includes the four canonical tags" do
    ids = DietaryTags.ids()
    assert "vegetarian" in ids
    assert "vegan" in ids
    assert "gluten_free" in ids
    assert "dairy_free" in ids
  end
end
