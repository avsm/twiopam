FROM ocaml/opam
RUN sudo apt-get update && sudo apt-get -y install uchardet recode
RUN opam pin add -n opamfu --dev && opam depext -uiyv -j 2 opamfu
RUN opam pin add -n twiopam https://github.com/avsm/twiopam.git && opam depext -uiyv -j 2 twiopam
RUN opam pin add -n github https://github.com/mirage/ocaml-github.git && opam depext -uiv -j 2 github
ENTRYPOINT ["opam","config","exec","--","twiopam-run"]
