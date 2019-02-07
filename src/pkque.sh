#!/bin/sh

set -e

LIBEXEC=${LIBEXEC:-/usr/libexec/pkutils}
. $LIBEXEC/foundation.sh

$LIBEXEC/query.sh $*

TOTAL_PACKAGES=$(cat $PM_TMPDIR/count.tmp)

if [ $TOTAL_PACKAGES -eq 0 ]; then
  echo "No packages found." >&2
else
  awk -F ':' \
    '{ printf "%-12s %s\n", $1, $5 }' \
    $PM_TMPDIR/result.tmp
  echo "Total packages: $TOTAL_PACKAGES"
fi

rm -rf $PM_TMPDIR
