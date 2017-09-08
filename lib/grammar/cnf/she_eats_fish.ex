defmodule Glif.Grammar.CNF.SheEatsFish do
  @behaviour Glif.Grammar.CNF
  @moduledoc """
  Toy CNF grammar to test parser.
  """

  ###########################################################################
  # Grammar definition
  ###########################################################################

  # Note these are a bit backward from written CNF; we're function clause matching on the RHS
  # and returning the rolled-up LHS.

  # Terminals
  def terminal("eats"), do: [{"V", "eats"}]
  def terminal("she"), do: [{"NP", "she"}]
  def terminal("with"), do: [{"P", "with"}]
  def terminal("fish"), do: [{"N", "fish"}]
  def terminal("fork"), do: [{"N", "fork"}]
  def terminal("a"), do: [{"Det", "a"}]
  def terminal("the"), do: [{"Det", "the"}]

  # Terminal catchall
  def terminal(_), do: nil

  # Rules
  def rule(b = {"NP", _}, c = {"VP", _}), do: [{"S", {b, c}}]
  def rule(b = {"VP", _}, c = {"PP", _}), do: [{"VP", {b, c}}]
  def rule(b = {"V", _}, c = {"NP", _}), do: [{"VP", {b, c}}]
  def rule(b = {"P", _}, c = {"NP", _}), do: [{"PP", {b, c}}]
  def rule(b = {"Det", _}, c = {"N", _}), do: [{"NP", {b, c}}]

  # Rule catchall
  def rule(_b, _c), do: nil

  # Split string into tokens
  def tokenize(sent) do
    # Dirt. Simple. For testing only.
    sent
    |> String.downcase()
    |> String.split()
  end

end
