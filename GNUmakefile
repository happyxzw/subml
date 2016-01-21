all: subml.byte subml.native

DESTDIR=/usr/local/bin
MLFILES=bindlib/bindlib_util.ml bindlib/bindlib.ml \
        decap/ahash.ml decap/ptmap.ml decap/input.ml decap/decap.ml \
        util.ml io.ml timed_ref.ml ast.ml eval.ml print.ml latex.ml sct.ml \
	proof_trace.ml raw.ml typing.ml print_trace.ml latex_trace.ml parser.ml

parser.ml: parser.dml
	pa_ocaml --ascii --impl parser.dml > parser.ml

subml.native: $(MLFILES) subml.ml
	ocamlbuild -cflags -w,-3-30 -use-ocamlfind $@

subml.byte: $(MLFILES) subml.ml
	ocamlbuild -cflags -w,-3-30 -use-ocamlfind $@

submljs.byte: $(MLFILES) submljs.ml
	ocamlbuild -pkgs lwt.syntax,js_of_ocaml,js_of_ocaml.syntax -cflags -syntax,camlp4o,-w,-3-30 -use-ocamlfind $@

subml.js: submljs.byte
	js_of_ocaml --pretty +weak.js submljs.byte -o subml.js

installjs: subml.js subml-latest.tar.gz
	cp subml.js ../subml/subml/
	scp subml.js lama.univ-savoie.fr:/home/rlepi/WWW/subml/subml/
	rm -f lib/*~
	scp -r lib lama.univ-savoie.fr:/home/rlepi/WWW/subml/subml/
	scp subml-latest.tar.gz lama.univ-savoie.fr:/home/rlepi/WWW/subml/docs/

rodinstalljs: subml.js subml-latest.tar.gz
	scp subml.js rlepi@lama.univ-savoie.fr:/home/rlepi/WWW/subml/subml/
	rm -f lib/*~
	scp -r lib rlepi@lama.univ-savoie.fr:/home/rlepi/WWW/subml/subml/
	scp subml-latest.tar.gz rlepi@lama.univ-savoie.fr:/home/rlepi/WWW/subml/docs/

run: all
	ledit ./subml.native

test: all
	./subml.native --quit lib/all.typ

clean:
	ocamlbuild -clean

distclean: clean
	rm -f *~ lib/*~
	rm -rf subml-latest subml-latest.tar.gz

install: all
	install ./subml.native $(DESTDIR)/subml

subml-latest.tar.gz: parser.ml
	rm -rf subml-latest
	mkdir subml-latest
	cp -r decap subml-latest
	cp -r bindlib subml-latest
	cp parser.ml subml-latest
	cp util.ml io.ml timed_ref.ml ast.ml eval.ml print.ml subml-latest
	cp latex.ml sct.ml proof_trace.ml raw.ml typing.ml subml-latest
	cp print_trace.ml latex_trace.ml parser.ml subml.ml subml-latest
	cp Makefile_minimum subml-latest/Makefile
	cp _tags subml-latest
	rm -f lib/*~
	cp -r lib subml-latest
	tar zcvf subml-latest.tar.gz subml-latest
	rm -r subml-latest
