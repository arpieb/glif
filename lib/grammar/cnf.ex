defmodule Glif.Grammar.CNF do
  @moduledoc ~S"""
  This module defines a behaviour for a Chomsky Normal Form (CNF) grammar to be
  used by a Cocke–Younger–Kasami (CYK) chart parser.
  """

  @doc ~S"""
  Tokenizes the provided String and returns a list of String tokens.
  """
  @callback tokenize(String.t) :: [String.t]

  @doc ~S"""
  Defines a CNF bigram rule (A -> BC) where the arguments are B, C and the
  return is a list of matching A, or nil if no match is found.
  """
  @callback rule(any, any) :: [tuple] | nil

  @doc ~S"""
  Defines a CNF terminal rule (A -> <token>) where the argument is the terminal
  token and the return is a list of matching A, or nil if no match is found.
  """
  @callback terminal(String.t) :: [tuple] | nil
end
