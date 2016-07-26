#!/bin/sh -e
# Run TWiOPAM in a container

WRKDIR=/home/opam
TMPREPO=${WRKDIR}/opam-repository
OUTDIR=/out

case $1 in
--help)
  twiopam --help
  exit 0
  ;;
*)
  ;;
esac

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
find ${OUTDIR} -type f -name '*.txt' | while read FFN
do
    encoding=`uchardet "$FFN" | awk -F/ '{print $1}'`
    enc=`echo $encoding | sed 's#^x-mac-#mac#'`
    recode $enc..UTF-8 "$FFN"
done
