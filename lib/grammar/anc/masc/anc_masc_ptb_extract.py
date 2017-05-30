from nltk.corpus.reader.bracket_parse import *

reader = BracketParseCorpusReader('masc-penn-treebank/', '.*/.*/.*\.mrg', detect_blocks='sexpr')

# print "\n".join(reader.fileids())

terminal = set()
binary = set()
for fileid in reader.fileids():
    for sent in reader.parsed_sents(fileid):
        if sent.label() != 'CODE':
            try:
                sent.chomsky_normal_form()
                for p in sent.productions():
                    if p.is_lexical():
                        terminal.add(p.unicode_repr())
                    else:
                        binary.add(p.unicode_repr())
            except Exception:
                pass

print "TERMINALS"
print "\n".join(terminal)
print
print "BINARIES"
print "\n".join(binary)
