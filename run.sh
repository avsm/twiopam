#!/bin/sh -e

WRKDIR=/home/opam
TMPREPO=${WRKDIR}/opam-repository
OUTDIR=${WRKDIR}/out

if [ ! -d ${TMPREPO} ]; then
  git clone git://github.com/ocaml/opam-repository ${TMPREPO}
else
  git -C ${TMPREPO} pull origin master
fi

mkdir -p out/cache
export OPAMROOT=/tmp/.local-opam
if [ -d ${OPAMROOT} ]; then
  opam update -u -y
else
  opam init -y -k git ${TMPREPO}
fi
twiopam -d ${OUTDIR} $* path:${TMPREPO}
