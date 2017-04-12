defmodule CYKParser.Grammar.CoreNLPEnglishPCFG do
  @moduledoc """
  This grammar module provides a codified version of the [Stanford CoreNLP Parser](https://nlp.stanford.edu/software/lex-parser.shtml)
  PCFG English grammar, exported from the Java codebase per the project's [FAQ](https://nlp.stanford.edu/software/parser-faq.shtml#grammar)

  For posterity's sake, in the event the FAQ disappears, you can extract the grammar
  by downloading at a minimum the parser distro and executing the following command:

  ```java
  java -cp "*" edu.stanford.nlp.parser.lexparser.LexicalizedParser -loadFromSerializedFile edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz -saveToTextFile englishPCFG.txt
  ```

  This will generate a file named `englishPCFG.txt` that contains the exported grammar.
  Caveats from the Stanford FAQ:

  * The grammar is induced from data, not hand-written, and so expect something messy and ugly.
  * It’s already a binarized grammar with automatically generated labels for binarized nodes.
  * It includes the kind of state refinement introduced in the [Klein and Manning (2003) paper](https://nlp.stanford.edu/software/lex-parser.shtml#Citing).
  * The grammar includes word class based signatures for unknown words, and to fully use the grammar, you have to map unknown words on to those signatures.

  The PCFG export bundled with this codebase was exported from CoreNLP v3.7.0.
  """
  @behaviour CYKParser.Grammar

  # Some handy module attributes for locating assets.
  @external_resource pcfg_path = Path.join([__DIR__, "englishPCFG.txt"])

  defmodule CoreNLPGrammar do
    @moduledoc ~S"""
    Helper module to be used only with the CYKParser.Grammar.CoreNLPEnglishPCFG module to process the PCFG export.
    """

    # Struct holds the major sections we will extract from the PCFG.
    defstruct cur_section: nil, lexicon: %{}, unary_grammar: %{}, binary_grammar: %{}

    # Process Stanford CoreNLP PCFG export file
    def parse_pcfg(pcfg_path) do
        File.stream!(pcfg_path, [:read, :utf8])
        |> Enum.reduce(%CoreNLPGrammar{}, &CoreNLPGrammar.process_line/2)
    end

    # Process a line from the file into the grammar being built.
    # Note the normal param order is swapped since this is being called from a reduce function.
    def process_line(line, grammar = %CoreNLPGrammar{cur_section: :lexicon}) do
      # Example: "IN^PP-SC" -> "For" SEEN 461.060528852118
      re = ~r/"(?<left>.*)"\s->\s"(?<right>.*)"\s(UN)?SEEN\s(?<seen>.*)/
      update_lexicon(grammar, Regex.named_captures(re, line))
    end
    def process_line(line, grammar = %CoreNLPGrammar{cur_section: :unary_grammar}) do
      # Example: "@S^ROOT-v| S^S-v_" -> "S^S-v" -10.541796
      re = ~r/"(?<left>.*)"\s->\s"(?<right>.*)"\s(?<prob>.*)/
      update_unary_grammar(grammar, Regex.named_captures(re, line))
    end
    def process_line(line, grammar = %CoreNLPGrammar{cur_section: :binary_grammar}) do
      # Example: "@NodeSet-655369574" -> "INTJ-v" "@S^S-v| VP^S-VB-v_" -3.1780539
      re = ~r/"(?<left>.*)"\s->\s"(?<r1>.*)"\s"(?<r2>.*)"\s(?<prob>.*)/
      update_binary_grammar(grammar, Regex.named_captures(re, line))
    end
    def process_line(line, grammar) do
      case line do
        "BEGIN LEXICON" <> _rest ->
          Map.put(grammar, :cur_section, :lexicon)
        "BEGIN UNARY_GRAMMAR" <> _rest ->
          Map.put(grammar, :cur_section, :unary_grammar)
        "BEGIN BINARY_GRAMMAR" <> _rest ->
          Map.put(grammar, :cur_section, :binary_grammar)
        _ -> grammar
      end
    end

    # Add/update terminal in from PCFG lexicon.
    defp update_lexicon(grammar, nil) do
      Map.put(grammar, :cur_section, nil)
    end
    defp update_lexicon(grammar, %{"left" => left, "right" => right, "seen" => seen}) do
      lexicon = Map.get(grammar, :lexicon, %{})
      symbols = [{left, right, String.to_float(seen)} | Map.get(lexicon, right, [])]
      Map.put(grammar, :lexicon, Map.put(lexicon, right, symbols))
    end

    # Add/update unary grammar from PCFG.
    defp update_unary_grammar(grammar, nil) do
      Map.put(grammar, :cur_section, nil)
    end
    defp update_unary_grammar(grammar, %{"left" => left, "right" => right, "prob" => prob}) do
      u_grammar = Map.get(grammar, :unary_grammar, [])
      rules = [{left, right, String.to_float(prob)} | Map.get(u_grammar, right, [])]
      Map.put(grammar, :unary_grammar, Map.put(u_grammar, right, rules))
    end

    # Add/update binary grammar from PCFG.
    defp update_binary_grammar(grammar, nil) do
      Map.put(grammar, :cur_section, nil)
    end
    defp update_binary_grammar(grammar, %{"left" => left, "r1" => r1, "r2" => r2, "prob" => prob}) do
      b_grammar = Map.get(grammar, :binary_grammar, [])
      key = {r1, r2}
      rules = [{left, {r1, r2}, String.to_float(prob)} | Map.get(b_grammar, key, [])]
      Map.put(grammar, :binary_grammar, Map.put(b_grammar, key, rules))
    end
  end

  # Get start time for reporting
  start = System.monotonic_time()
  IO.puts("Compiling Stanford CoreNLP English PCFG export to static lookups takes a while...")

  # Extract grammar maps from Stanford CoreNLP English PCFG export
  IO.puts("Parsing PCFG export...")
  %{lexicon: lexicon, unary_grammar: u_grammar, binary_grammar: b_grammar} = CoreNLPGrammar.parse_pcfg(@external_resource)
  IO.puts("Extracted " <> Integer.to_string(Enum.count(lexicon)) <> " terminals")
  IO.puts("          " <> Integer.to_string(Enum.count(u_grammar)) <> " unary rules")
  IO.puts("          " <> Integer.to_string(Enum.count(b_grammar)) <> " binary rules")

  IO.puts("Generating grammar function heads...")

  # Util functions to perform grammar lookups
  defp get_lexicon(), do: unquote(Macro.escape(lexicon))
  defp get_unary_grammar(), do: unquote(Macro.escape(u_grammar))
  defp get_binary_grammar(), do: unquote(Macro.escape(b_grammar))

  # End timer
  elapsed = (System.monotonic_time() - start) |> System.convert_time_unit(:native, :millisecond)
  IO.puts("Codified Stanford CoreNLP English PCFG export in #{elapsed}ms")

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
    process_rule_lookup(Map.get(get_binary_grammar(), {r1_key, r2_key}, nil), r1, r2)
  end

  # Util function to help process binary grammar lookup results
  defp process_rule_lookup(matches, r1, r2) when is_list(matches) do
    for {left, _, prob} <- matches do
      {left, {r1, r2}, prob}
    end
  end
  defp process_rule_lookup(nil, _r1, _r2) do
    nil
  end

  @doc ~S"""
  Tokenizes the provided String and returns a list of String tokens.
  """
  def tokenize(sent) do
    # Dirt. Simple. For testing only.
    # TODO implement a tokenizer analogous to the CoreNLP parser for best results.
    String.split(sent)
  end

end
