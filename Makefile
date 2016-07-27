.PHONY: all clean run

TMPREPO=/home/opam/opam-tmp-repository
all: twiopam.native
	@ :

twiopam.native: twiopam.ml
	ocamlbuild -use-ocamlfind -tag annot,bin_annot,debug,principal -pkgs opam-lib,opamfu.cli,ptime,fmt,calendar twiopam.native

run:
	if [ ! -d $(TMPREPO) ]; then git clone git://github.com/ocaml/opam-repository $(TMPREPO); else git -C $(TMPREPO) pull origin master; fi
	rm -rf out && mkdir -p out/cache
	set -ex; export OPAMROOT=`pwd`/.local-opam; \
	  if [ -d .local-opam ]; then \
	    opam update -u -y; \
	  else \
	    opam init -y -k git $(TMPREPO); \
	  fi; \
	./twiopam.native -d out path:$(TMPREPO)

clean:
	ocamlbuild -clean
