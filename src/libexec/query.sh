#!/bin/sh

while [ -n "$1" ]; do
  case $1 in
    -s | --strict) STRICT=yes ;;
    -m | --instamode) INSTAMODE=1 ;;
    -?=* | --*=*)
      OPTION=$(echo $1 | cut -d= -f1)
      VALUE=$(echo $1 | cut -d= -f2)
      if [ "$STRICT" = "yes" ]; then
        VALUE="^$VALUE\$"
      fi
      case $OPTION in
        -r | --repo)    REPO_QUERY="$REPO_QUERY|$VALUE" ;;
        -e | --series)  SERIES_QUERY="$SERIES_QUERY|$VALUE" ;;
        -v | --version) VERSION_QUERY="$VERSION_QUERY|$VALUE" ;;
        -a | --arch)    ARCH_QUERY="$ARCH_QUERY|$VALUE" ;;
        -t | --tag)     TAG_QUERY="$TAG_QUERY|$VALUE" ;;
        *) echo "Unknown option $OPTION!" >&2 ;;
      esac
      ;;
    *)
      if [ "$STRICT" = "yes" ]; then
        NAME_QUERY="${NAME_QUERY}|^${1}\$"
      else
        NAME_QUERY="${NAME_QUERY}|${1}"
      fi
      ;;
  esac
  shift
done

REPO_QUERY=$(echo $REPO_QUERY | cut -c2-)
SERIES_QUERY=$(echo $SERIES_QUERY | cut -c2-)
NAME_QUERY=$(echo $NAME_QUERY | cut -c2-)
VERSION_QUERY=$(echo $VERSION_QUERY | cut -c2-)
ARCH_QUERY=$(echo $ARCH_QUERY | cut -c2-)
TAG_QUERY=$(echo $TAG_QUERY | cut -c2-)

awk -v REPO_QUERY=${REPO_QUERY:-'.*'} \
    -v SERIES_QUERY=${SERIES_QUERY:-'.*'} \
    -v NAME_QUERY=${NAME_QUERY:-'.*'} \
    -v VERSION_QUERY=${VERSION_QUERY:-'.*'} \
    -v ARCH_QUERY=${ARCH_QUERY:-'.*'} \
    -v TAG_QUERY=${TAG_QUERY:-'.*'} \
    -v INSTAMODE=${INSTAMODE:-0} \
    -f $LIBEXEC/query.awk $PM_WD/index.dat \
    > $PM_TMPDIR/result.tmp 2> $PM_TMPDIR/count.tmp
