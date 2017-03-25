defmodule SheEatsFish do
  ###########################################################################
  # Grammar definition
  ###########################################################################

  # Note these are a bit backward from written CNF; we're function clause matching on the RHS
  # and returning the rolled-up LHS.

  # Terminals
  def word("eats"), do: {:V, "eats"}
  def word("she"), do: {:NP, "she"}
  def word("with"), do: {:P, "with"}
  def word("fish"), do: {:N, "fish"}
  def word("fork"), do: {:N, "fork"}
  def word("a"), do: {:Det, "a"}
  def word("the"), do: {:Det, "the"}

  # Terminal catchall
  def word(_), do: nil

  # Rules
  def rule(b = {:NP, _}, c = {:VP, _}), do: {:S, {b, c}}
  def rule(b = {:VP, _}, c = {:PP, _}), do: {:VP, {b, c}}
  def rule(b = {:V, _}, c = {:NP, _}), do: {:VP, {b, c}}
  def rule(b = {:P, _}, c = {:NP, _}), do: {:PP, {b, c}}
  def rule(b = {:Det, _}, c = {:N, _}), do: {:NP, {b, c}}

  # Rule catchall
  def rule(_b, _c), do: nil

  # Split string into tokens
  def tokenize(sent) do
    # Dirt. Simple. For testing only.
    String.split(sent)
  end

end

defmodule CYKParser do
  @moduledoc """
  Documentation for CYKParser.

  Based on "chart parsing" approach presented in:
  http://www.inf.ed.ac.uk/teaching/courses/inf2a/slides/2011_inf2a_L17_slides.pdf
  """

  ###########################################################################
  # Parser code
  ###########################################################################
  # Implements CYK parser
  def parse(sent, grammar) do
    # Tokenize sentence
    tokens = apply(grammar, :tokenize, [sent])

    # Set up CYK lookup table
    num_tokens = Enum.count(tokens)
    create_table(num_tokens, nil)
    |> parse_to_table(grammar, tokens)
    |> get_in([0, num_tokens])
  end

  # Tail-recursive function to process our tokens into a CYK table
  defp parse_to_table(table, _grammar, []) do
    # Terminate recursion
    table
  end
  defp parse_to_table(table, grammar, tokens) do
    # Orient ourselves on the table
    j = Enum.count(table) - Enum.count(tokens) + 1

    # Add applicable rules if any to table for this token, then update table based on previous rules; recurse
    word = apply(grammar, :word, [hd(tokens)])
    put_in(table[j - 1][j], word)
    |> fill_row_in_column(grammar, j - 2, j)
    |> parse_to_table(grammar, tl(tokens))
  end

  # Update table with backreferences based on recently added material.
  defp fill_row_in_column(table, grammar, i, j) when i >= 0 do
    process_split_locations(table, grammar, i , j, i + 1)
    |> fill_row_in_column(grammar, i - 1, j)
  end
  defp fill_row_in_column(table, _grammar, _i, _j) do
    # Terminate recursion
    table
  end

  # Process split locations
  defp process_split_locations(table, grammar, i, j, k) when k < j do
    b = table[i][k]
    c = table[k][j]
    match = apply(grammar, :rule, [b, c])

    case match do
      nil -> table
      _ -> put_in(table[i][j], match)
    end
    |> process_split_locations(grammar, i, j, k + 1)
  end
  defp process_split_locations(table, _grammar, _i, _j, _k) do
    # Terminate recursion
    table
  end

  # Create custom-indexed map-based table for building our CYK parse chart.
  defp create_table(num_tokens, initial) do
    for r <- 0..(num_tokens - 1), into: %{} do
      colmap = for c <- 1..(r + 1), into: %{} do
        {c, initial}
      end
      {r, colmap}
    end
  end
end
