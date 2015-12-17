all: main.native main.byte

DESTDIR=/usr/local/bin
MLFILES=util.ml ast.ml eval.ml print.ml multi_print.ml latex.ml \
	trace.ml latex_trace.ml typing.ml dparser.ml main.ml

main.native: $(MLFILES)
	ocamlbuild -quiet -use-ocamlfind $@

main.byte: $(MLFILES)
	ocamlbuild -quiet -use-ocamlfind $@

run: all
	ledit ./main.native

test: all
	ledit ./main.native lib/all.typ

clean:
	ocamlbuild -clean

distclean: clean
	rm -f *~ lib/*~

install: all
	install ./main.byte $(DESTDIR)/proto.byt
