FROM ocaml/opam:alpine
RUN opam pin add -n opamfu --dev
RUN opam pin add -n twiopam https://github.com/avsm/twiopam.git
RUN opam depext -u twiopam
RUN opam install -j 2 -y -v twiopam
ENTRYPOINT ["opam","config","exec","--","twiopam-run"]
