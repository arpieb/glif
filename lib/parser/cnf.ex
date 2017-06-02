defmodule Glif.Parser.CNF do
  @moduledoc ~S"""
  This module defines a behaviour for a Chomsky Normal Form (CNF) grammar-driven
  parser.
  """

  @doc ~S"""
  Execute parse on a sentence using the specified Glif.Grammar.CNF module.
  """
  @callback parse(sent :: binary, module) :: tuple | nil
end
