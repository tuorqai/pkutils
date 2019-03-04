#!/bin/sh

if [ "$DRYRUN" = "yes" ]; then
  V="echo >>>"
fi

interrupt() {
  exit 200
}

trap interrupt SIGINT

SLACKBUILD_NAME="$1"
REPO_NAME="$2"
SYSCOM="$3"

export OUTPUT=$PK_CACHEDIR/$REPO_NAME
export VERSION
export BUILD
export TAG

$V cd $PK_LIBDIR/repo_$REPO_NAME
$V tar xvf $SLACKBUILD_NAME.tar.gz || exit 1

$V cd $PK_LIBDIR/repo_$REPO_NAME/$SLACKBUILD_NAME
set -e
$V . ./$SLACKBUILD_NAME.SlackBuild
set +e

$V $SYSCOM $OUTPUT/$PRGNAM-$VERSION-$ARCH-$BUILD$TAG.t?z
