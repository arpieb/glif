defmodule CYKParser.Grammar.ANC.MASC.PTB do
  @moduledoc """
  This grammar module provides a codified version of a CNF grammar extracted from
  the [American National Corpus' Manually Annotated Sub-Corpus](http://www.anc.org/data/masc/)
  Penn Treebank (PTB) source files for English.

  The CNF grammar included here was generated using [NLTK](http://www.nltk.org/) to process the PTB
  annotations from the v3.0.0 release of MASC PTB data.  The Python script is
  included in this module's directory as `anc_masc_ptb_extract.py`.

  (If anyone knows of - or would like to build - a PTB native parser in Elixir
  that can extract grammar production rules, please feel free to contribute!)
  """
  @behaviour CYKParser.Grammar

  # Some handy module attributes for locating assets.
  @external_resource cnf_path = Path.join([__DIR__, "anc_masc_ptb_v300.cnf"])

  defmodule ANCMASCPTBGrammar do
    @moduledoc ~S"""
    Helper module to be used only with the CYKParser.Grammar.ANCMASCPTB module to process the CNF export.
    """

    # Struct holds the major sections we will extract from the PCFG.
    defstruct lexicon: %{}, rules: %{}

    # Process Stanford CoreNLP PCFG export file
    def parse_cnf(cnf_path) do
        File.stream!(cnf_path, [:read, :utf8])
        |> Enum.reduce(%ANCMASCPTBGrammar{}, &ANCMASCPTBGrammar.process_line/2)
    end

    # Process a line from the file into the grammar being built.
    # Note the normal param order is swapped since this is being called from a reduce function.
    def process_line(line, grammar) do
      line = String.trim(line)

      # Define regex patterns for lexicon/rule extraction
      re_lexicon = ~r/(?<left>\S+)\s+->\s+['"](?<right>.+)['"]/ # Example: VBZ -> 'exaggerates'
      re_rule = ~r/(?<left>\S+)\s+->\s+(?<r1>\S+)\s+(?<r2>\S+)/ # Example: VP -> VB VP|<ADVP-MNR-S>

      # Pipe grammar through potential lexicon/rule updates from current CNF line
      grammar
      |> update_lexicon(Regex.named_captures(re_lexicon, line))
      |> update_rules(Regex.named_captures(re_rule, line))
    end

    # Add/update terminal from CNF lexicon.
    defp update_lexicon(grammar, %{"left" => left, "right" => right}) do
      lexicon = Map.get(grammar, :lexicon, %{})
      symbols = [{left, right} | Map.get(lexicon, right, [])]
      Map.put(grammar, :lexicon, Map.put(lexicon, right, symbols))
    end
    defp update_lexicon(grammar, _other), do: grammar

    # Add/update binary grammar from CNF rules.
    defp update_rules(grammar, %{"left" => left, "r1" => r1, "r2" => r2}) do
      b_grammar = Map.get(grammar, :rules, [])
      key = {r1, r2}
      rules = [{left, key} | Map.get(b_grammar, key, [])]
      Map.put(grammar, :rules, Map.put(b_grammar, key, rules))
    end
    defp update_rules(grammar, _other), do: grammar
  end

  # Get start time for reporting
  start = System.monotonic_time()
  IO.puts("Compiling ANC MASC PTB CNF (whew!) export to static lookups takes a while...")

  # Extract grammar maps from Stanford CoreNLP English PCFG export
  IO.puts("Parsing CNF export...")
  %{lexicon: lexicon, rules: rules} = ANCMASCPTBGrammar.parse_cnf(@external_resource)
  IO.puts("Extracted " <> Integer.to_string(Enum.count(lexicon)) <> " terminals")
  IO.puts("          " <> Integer.to_string(Enum.count(rules)) <> " rules")

  IO.puts("Generating grammar function heads...")

  # Util functions to perform grammar lookups
  defp get_lexicon(), do: unquote(Macro.escape(lexicon))
  defp get_rules(), do: unquote(Macro.escape(rules))

  # End timer
  elapsed = (System.monotonic_time() - start) |> System.convert_time_unit(:native, :millisecond)
  IO.puts("Codified ANC MASC PTB CNF export in #{elapsed}ms")

  @doc ~S"""
  Perform a lookup for a terminal in the CNF grammar.

  The CNF rule is of the form A -> <word> and the lookup is performed on the word
  to return a list of terminal symbol matches in the form `[{A, <word>, <seen>}]`
  or `nil` if no match.

  Examples:
      iex> CYKParser.Grammar.CoreNLPEnglishPCFG.terminal("house")
      [{".*.", "house", 131.5}, {"VB^VP", "house", 5.0}, {"NN^NP", "house", 126.5}]

      iex> CYKParser.Grammar.CoreNLPEnglishPCFG.terminal("foo")
      nil
  """
  def terminal(word) do
    Map.get(get_lexicon(), word, nil)
  end

  @doc ~S"""
  Perform a lookup for a binary rule in the CNF grammar.

  The CNF rule is of the form A -> BC and the lookup is performed on B and C to
  return a list of matches in the form `[{A, {B, C}, <probability>}]` or `nil` if
  no match.

  Examples:
      iex> CYKParser.Grammar.CoreNLPEnglishPCFG.rule({"@VP-VB-v| VB^VP_ NP-TMP^VP-B>", 1}, {"PP^VP-v", 2})
      [{"@NodeSet-2113108137", {{"@VP-VB-v| VB^VP_ NP-TMP^VP-B>", 1}, {"PP^VP-v", 2}},
      -0.22314358}]

      iex> CYKParser.Grammar.CoreNLPEnglishPCFG.rule({"foo", 1}, {"bar", 2})
      nil
  """
  def rule(r1, r2) when is_tuple(r1) and is_tuple(r2) do
    r1_key = elem(r1, 0)
    r2_key = elem(r2, 0)
    process_rule_lookup(Map.get(get_rules(), {r1_key, r2_key}, nil), r1, r2)
  end

  # Util function to help process binary grammar lookup results
  defp process_rule_lookup(matches, r1, r2) when is_list(matches) do
    for {left, _} <- matches do
      {left, {r1, r2}}
    end
  end
  defp process_rule_lookup(nil, _r1, _r2), do: nil

  @doc ~S"""
  Tokenizes the provided String and returns a list of String tokens.
  """
  def tokenize(sent) do
    # Dirt. Simple. For testing only.
    # TODO implement a real tokenizer...
    String.split(sent)
  end

end
