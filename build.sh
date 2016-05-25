#!/bin/sh -e

ocamlbuild -use-ocamlfind -tag annot -pkgs opamfu.cli,ptime twiopam.native
