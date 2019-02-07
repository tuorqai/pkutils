#!/bin/sh

answer() {
  if [ -n "$DEFAULT_ANSWER" ]; then
    echo "$DEFAULT_ANSWER"
    ANSWER=$DEFAULT_ANSWER
  else
    read ANSWER
  fi
}

PM_WD=${PM_WD:-/var/lib/pkutils}
PM_CACHEDIR=${PM_CACHEDIR:-/var/cache/pkutils}
PM_TMPDIR=${PM_TMPDIR:-}
PM_ROOT=${PM_ROOT:-}
PM_CONFDIR=${PM_CONFDIR:-/etc/pkutils}

mkdir -p $PM_WD
mkdir -p $PM_CACHEDIR

if [ -n "$PM_TMPDIR" ]; then
  # if [ -e "$PM_TMPDIR" ]; then
  #   echo "Temporary directory exists already. Backing up..." >&2
  #   mv $PM_TMPDIR $PM_TMPDIR-bak-$(date +%Y%m%d-%H%M%S)
  # fi
  rm -rf $PM_TMPDIR
  mkdir -p $PM_TMPDIR
else
  PM_TMPDIR=$(mktemp -p /tmp -d pkutils.XXXXXX 2>/dev/null)
  if [ $? -ne 0 ]; then
    PM_TMPDIR=/tmp/pkutils
    # mv $PM_TMPDIR $PM_TMPDIR-bak-$(date +%Y%m%d-%H%M%S) >/dev/null 2>/dev/null
    rm -rf $PM_TMPDIR
    mkdir -p $MP_TMPDIR
  fi
fi

if [ -n "$PM_ROOT" ] && [ ! -d "$PM_ROOT" ]; then
  echo "Other root is set but that directory doesn't exist." >&2
  echo "Aborting." >&2
  exit 1
fi

find /var/log/packages -type f -printf "%f\n" > $PM_TMPDIR/pklist.tmp