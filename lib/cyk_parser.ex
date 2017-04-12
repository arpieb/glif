defmodule CYKParser do
  @moduledoc """
  A basic Cocke–Younger–Kasami (CYK) chart parser.

  The parser operates with a grammar module name that implements the
  CYKParser.Grammar behaviour.
  """

  @doc ~S"""
  Parses the provided sentence into a parse tree using the provided grammar
  module, or returns `nil` if it does not parse.

  The sentence must be an Elixir binary, and the grammar module must
  implement the CYKParser.Grammar behaviour.

  Examples:
      iex> CYKParser.parse("she eats the fish with a fork", CYKParser.Grammar.SheEatsFish)
      {:S,
       {{:NP, "she"},
        {:VP,
         {{:VP, {{:V, "eats"}, {:NP, {{:Det, "the"}, {:N, "fish"}}}}},
          {:PP, {{:P, "with"}, {:NP, {{:Det, "a"}, {:N, "fork"}}}}}}}}}

      iex> CYKParser.parse("this will not parse", CYKParser.Grammar.SheEatsFish)
      nil
  """
  @spec parse(sent :: binary, module) :: tuple | nil
  def parse(sent, grammar, verbose \\ false) do
    # Tokenize sentence
    tokens = apply(grammar, :tokenize, [sent])

    # Set up CYK lookup table
    num_tokens = Enum.count(tokens)
    chart = create_table(num_tokens)
    |> parse_to_table(grammar, tokens)

    if (verbose) do
      IO.inspect(chart)
    end

    chart
    |> get_in([0, num_tokens])
  end

  # Tail-recursive function to process our tokens into a CYK table
  defp parse_to_table(table, grammar, tokens) do
    parse_to_table(table, grammar, tokens, 1)
  end
  defp parse_to_table(table, _grammar, [], _j) do
    # Terminate recursion
    table
  end
  defp parse_to_table(table, grammar, tokens, j) do
    # Add applicable rules if any to table for this token, then update table based on previous rules; recurse
    terminal = apply(grammar, :terminal, [hd(tokens)])
    put_in(table[j - 1][j], terminal)
    |> fill_row_in_column(grammar, j - 2, j)
    |> parse_to_table(grammar, tl(tokens), j + 1)
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
    b_all = table[i][k]
    c_all = table[k][j]

    put_in(table[i][j], MapSet.union(table[i][j], MapSet.new(match_rules(grammar, b_all, c_all))))
    |> process_split_locations(grammar, i, j, k + 1)
  end
  defp process_split_locations(table, _grammar, _i, _j, _k) do
    # Terminate recursion
    table
  end

  defp match_rules(grammar, b_all, c_all) when b_all != nil and c_all != nil do
    for b <- b_all, c <- c_all do
      apply(grammar, :rule, [b, c])
    end
    |> List.flatten()
    |> Enum.filter(&(&1))
  end
  defp match_rules(_grammar, _b_all, _c_call) do
    []
  end

  # Create custom-indexed map-based table for building our CYK parse chart.
  defp create_table(num_tokens) do
    for r <- 0..(num_tokens - 1), into: %{} do
      colmap = for c <- 1..(num_tokens), into: %{} do
        {c, MapSet.new()}
      end
      {r, colmap}
    end
  end
end
