#!/bin/sh

set -e

LIBEXEC=${LIBEXEC:-/usr/libexec/pkutils}
. $LIBEXEC/foundation.sh

while [ -n "$1" ]; do
  case $1 in
    -u | --upgrade ) UPGRADE=yes ;;
    -f | --reinstall ) FORCE=yes ;;
    # sanity check
    -?=* | --*=* )
      OPTION=$(echo $1 | cut -d= -f1)
      case $OPTION in
        -r | --repo | -e | --series | -v | --version | -a | --arch | -t | --tag )
          QUERY_ARGS="$QUERY_ARGS $1" ;;
        *)
          echo "Unrecognized argument: $1" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      QUERY_ARGS="$QUERY_ARGS $1"
      ;;
  esac
  shift
done

$LIBEXEC/query.sh --strict --instamode $QUERY_ARGS
TOTAL_PACKAGES=$(cat $PM_TMPDIR/count.tmp)
if [ $TOTAL_PACKAGES -eq 0 ]; then
  echo "No packages found." >&2
  rm -rf $PM_TMPDIR
  exit 1
fi

awk -v O_ADD=$PM_TMPDIR/add.tmp \
    -v O_XUP=$PM_TMPDIR/xup.tmp \
    -v O_GET=$PM_TMPDIR/fetch.tmp \
    -v UPGRADE=${UPGRADE:-no} \
    -v FORCE=${FORCE:-no} \
    -f $LIBEXEC/up2date.awk $PM_TMPDIR/pklist.tmp $PM_TMPDIR/result.tmp

if [ ! -f $PM_TMPDIR/fetch.tmp ]; then
  echo "Nothing to do."
  rm -rf $PM_TMPDIR
  exit 0
fi

while true; do
  TOTAL_FAILED=0

  while read RP_NAME RP_PROTOCOL PK_URL PK_FULLNAME PK_MD5SUM; do
    PK_FILE="$PM_CACHEDIR/$RP_NAME/$PK_FULLNAME"
    if [ -f "$PK_FILE" ]; then
      echo "$PK_MD5SUM $PK_FILE" | /usr/bin/md5sum --check >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "Package $PK_FULLNAME is downloaded already."
        continue
      fi
    fi

    case $RP_PROTOCOL in
      file)
        echo "Linking $PK_URL..."
        ln -sf $PK_URL $PK_FILE >/dev/null
        ;;
      http | https | ftp)
        wget -t 0 -c -O $PK_FILE "$RP_PROTOCOL://$PK_URL"
        if [ $? -ne 0 ]; then
          TOTAL_FAILED=$(($TOTAL_FAILED + 1))
          continue
        fi
        ;;
    esac

    echo "$PK_MD5SUM $PK_FILE" | /usr/bin/md5sum --check >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Error: $PK_FULLNAME: wrong MD5 checksum!" >&2
      TOTAL_FAILED=$(($TOTAL_FAILED + 1))
      continue
    fi
  done < $PM_TMPDIR/fetch.tmp

  if [ $TOTAL_FAILED -ne 0 ]; then
    echo "Failed to download $TOTAL_FAILED packages." >&2
    echo -e "Do you want to retry? (Y/n) \c"
    answer
    if [ "$ANSWER" = "N" -o "$ANSWER" = "n" ]; then
      exit 1
    fi
    continue
  fi

  break
done

if [ -f $PM_TMPDIR/add.tmp ]; then
  while read RP_NAME PK_FULLNAME; do
    PK_FILE=$PM_CACHEDIR/$RP_NAME/$PK_FULLNAME
    if [ -z "$PM_ROOT" ]; then
      echo installpkg $PK_FILE
    else
      echo installpkg --root $PM_ROOT $PK_FILE
    fi
  done < $PM_TMPDIR/add.tmp
fi

if [ -f $PM_TMPDIR/xup.tmp ]; then
  while read RP_NAME PK_FULLNAME; do
    PK_FILE=$PM_CACHEDIR/$RP_NAME/$PK_FULLNAME
    [ "$FORCE" = "yes" ] && UPGRADEPKG_ARGS="--reinstall"
    [ -n "$PM_ROOT" ] && UPGRADEPKG_ARGS="$UPGRADEPKG_ARGS --root $PM_ROOT"

    echo upgradepkg $UPGRADEPKG_ARGS $PK_FILE
  done < $PM_TMPDIR/xup.tmp
fi

echo "End."

# rm -rf $PM_TMPDIR