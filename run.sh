#!/bin/sh -e
# Run TWiOPAM in a container

WRKDIR=/home/opam
TMPREPO=${WRKDIR}/opam-repository
OUTDIR=/out

if [ ! -d ${TMPREPO} ]; then
  git clone -q git://github.com/ocaml/opam-repository ${TMPREPO}
else
  git -q -C ${TMPREPO} pull origin master
fi

mkdir -p out/cache
export OPAMROOT=/tmp/.local-opam
if [ -d ${OPAMROOT} ]; then
  opam update -q -u -y
else
  opam init -q -y -k git ${TMPREPO}
fi
twiopam -d ${OUTDIR} $* path:${TMPREPO}
