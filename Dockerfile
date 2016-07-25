FROM ocaml/opam:alpine
RUN opam pin add -n opamfu --dev
RUN opam pin add -n twiopam https://github.com/avsm/twiopam.git
RUN opam depext -uiyv -j 2 twiopam
ENTRYPOINT ["opam","config","exec","--","twiopam-run"]
