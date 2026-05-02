defmodule WPL.ValidatorTest do
  use ExUnit.Case
  doctest WPL.Validator

  test "greets the world" do
    assert WPL.Validator.hello() == :world
  end
end
