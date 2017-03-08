defmodule CYKParser do
  @moduledoc """
  Documentation for CYKParser.
  """

  ###########################################################################
  # Grammar definition
  ###########################################################################
  # Terminals
  def word("eats"), do: {:V, "eats"}
  def word("she"), do: {:NP, "she"}
  def word("with"), do: {:P, "with"}
  def word("fish"), do: {:N, "fish"}
  def word("fork"), do: {:N, "fork"}
  def word("a"), do: {:Det, "a"}
  def word(_), do: nil

  # Unary rules

  # Binary rules
  def rule(b = {:NP, _}, c = {:VP, _}), do: {:S, {b, c}}
  def rule(b = {:VP, _}, c = {:PP, _}), do: {:VP, {b, c}}
  def rule(b = {:V, _}, c = {:NP, _}), do: {:VP, {b, c}}
  def rule(b = {:P, _}, c = {:NP, _}), do: {:PP, {b, c}}
  def rule(b = {:Det, _}, c = {:N, _}), do: {:NP, {b, c}}
  def rule(_b, _c), do: nil

  ###########################################################################
  # Parser code
  ###########################################################################
  # Implements CYK parser
  def parse(sent) do
    # Tokenize sentence
    tokens = tokenize(sent)

    # Set up CYK lookup table
    num_tokens = Enum.count(tokens)
    create_table(num_tokens, nil)
    |> parse_to_table(tokens)
    |> get_in([0, num_tokens])
  end

  # Split string into tokens
  def tokenize(sent) do
    # Dirt. Simple. Test.
    String.split(sent)
  end

  # Tail-recursive function to process our tokens into a CYK table
  defp parse_to_table(table, []) do
    # Terminate recursion
    table
  end
  defp parse_to_table(table, tokens) do
    # Orient ourselves on the table
    j = Enum.count(table) - Enum.count(tokens) + 1

    # Add applicable rules if any to table for this token, then update table based on previous rules; recurse
    put_in(table[j - 1][j], word(hd(tokens)))
    |> fill_row_in_column(j - 2, j)
    |> parse_to_table(tl(tokens))
  end

  # Update table with backreferences based on recently added material.
  defp fill_row_in_column(table, i, j) when i >= 0 do
    process_split_locations(table, i , j, i + 1)
    |> fill_row_in_column(i - 1, j)
  end
  defp fill_row_in_column(table, _i, _j) do
    # Terminate recursion
    table
  end

  # Process split locations
  defp process_split_locations(table, i, j, k) when k < j do
    b = table[i][k]
    c = table[k][j]
    match = rule(b, c)

    case match do
      nil -> table
      _ -> put_in(table[i][j], match)
    end
    |> process_split_locations(i, j, k + 1)
  end
  defp process_split_locations(table, _i, _j, _k) do
    # Terminate recursion
    table
  end

  # Create custom-indexed map-based table for building our CYK parse chart.
  defp create_table(num_tokens, initial) do
    for r <- 0..(num_tokens - 1), into: %{} do
      colmap = for c <- 1..num_tokens, into: %{} do
        {c, initial}
      end
      {r, colmap}
    end
  end
end
