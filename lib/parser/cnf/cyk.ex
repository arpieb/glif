defmodule Glif.Parser.CNF.CYK do
  @behaviour Glif.Parser.CNF
  @moduledoc """
  A basic Cocke–Younger–Kasami (CYK) chart parser.

  The parser operates with a grammar module that implements the
  Glif.Grammar.CNF behaviour.
  """

  @doc ~S"""
  Parses the provided sentence into a parse tree using the provided grammar
  module, or returns `nil` if it does not parse.

  The sentence must be an Elixir binary, and the grammar module must
  implement the Glif.Grammar.CNF behaviour.
  """
  @spec parse(sent :: binary, module, target :: binary) :: [tuple] | nil
  def parse(sent, grammar, target \\ "S") do
    # Tokenize sentence
    tokens = apply(grammar, :tokenize, [sent])

    # Set up CYK lookup table
    num_tokens = Enum.count(tokens)
    create_table(num_tokens)
    |> parse_to_table(grammar, tokens)
    |> get_in([0, num_tokens])
    |> Enum.filter(fn({a, _, _}) -> a == target end)
  end

  # Tail-recursive function to process our tokens into a CYK table
  defp parse_to_table(table, grammar, tokens), do: parse_to_table(table, grammar, tokens, 1)
  defp parse_to_table(table, _grammar, [], _j), do: table
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
  defp fill_row_in_column(table, _grammar, _i, _j), do: table

  # Process split locations
  defp process_split_locations(table, grammar, i, j, k) when k < j do
    b_all = table[i][k]
    c_all = table[k][j]

    put_in(table[i][j], MapSet.union(table[i][j], MapSet.new(match_rules(grammar, b_all, c_all))))
    |> process_split_locations(grammar, i, j, k + 1)
  end
  defp process_split_locations(table, _grammar, _i, _j, _k), do: table

  defp match_rules(grammar, b_all, c_all) when b_all != nil and c_all != nil do
    for b <- b_all, c <- c_all do
      apply(grammar, :rule, [b, c])
    end
    |> List.flatten()
    |> Enum.filter(&(&1))
    |> filter_rules_by_probability()
  end
  defp match_rules(_grammar, _b_all, _c_call), do: []

  # Filter rules for this cell based on probabilities, if present as third term
  # in tuple: {lhs, rhs, prob}
  defp filter_rules_by_probability(rules) do
    rules
    |> Enum.map(&({&1, calc_probability(&1)}))        # Precalc all matched rule probabilities
    |> Enum.reduce(%{}, &acc_max_prob_rules/2)        # Reduce to set of highest probability rules for each LHS symbol
    |> Enum.map(fn({_a, {rule, _prob}}) -> rule end)  # Remove interim values from enumerable, back to list of rules
  end

  # Calculate rule probability.
  defp calc_probability({_a, {b, c}, prob}) do
    prob * calc_probability(b) * calc_probability(c)
  end
  defp calc_probability(_rule), do: 1.0

  # Reduce callback to take the max probability rule for each LHS symbol.
  defp acc_max_prob_rules(trule = {{a, _bc, _lprob}, prob}, acc) do
    case Map.get(acc, a) do
      nil ->
        Map.put(acc, a, trule)
      {_, cur_prob} ->
        if cur_prob < prob do
          Map.put(acc, a, trule)
        else
          acc
        end
      _ ->
        acc
    end
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
