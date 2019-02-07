#!/bin/sh

set -e

LIBEXEC=${LIBEXEC:-/usr/libexec/pkutils}
. $LIBEXEC/foundation.sh

NOW=$(date +%s)

awk -f $LIBEXEC/fmtrepos.awk $PM_CONFDIR/repos.list > $PM_WD/repos.dat

find $PM_WD -regex "$PM_WD/repo_.*" -type d | xargs rm -rf

# awk 'BEGIN { FS = ":" } { print $2 }' $PM_WD/repos.dat > $PM_WD/reponames.lst
cat /dev/null > $PM_WD/index.dat

IFS=":"

while read RP_TYPE RP_NAME RP_PROTOCOL RP_SERVER RP_ADDRESS; do
  RP_DIR=$PM_WD/repo_$RP_NAME
  mkdir -p $RP_DIR
  mkdir -p $PM_CACHEDIR/$RP_NAME

  case $RP_NAME in
    slackware | slackware64 | extra | pasture | patches | testing )
      RP_URL=$RP_SERVER/$RP_ADDRESS/$RP_NAME ;;
    *)
      RP_URL=$RP_SERVER/$RP_ADDRESS ;;
  esac

  echo "[$RP_TYPE] Updating $RP_PROTOCOL://$RP_URL..."

  case $RP_TYPE in
    pk) INDEX=PACKAGES.TXT ;;
    sb) INDEX=SLACKBUILDS.TXT ;;
    *) echo "Internal error: bad \$RP_TYPE." >&2 ; exit 1 ;;
  esac

  case $RP_PROTOCOL in
    file)
      if [ -n "$RP_SERVER" ]; then
        echo "-- Only local machine for file:// is supported." >&2
        continue
      fi

      if [ ! -f "$RP_URL/$INDEX" ]; then
        echo "-- Error: no package repository in \"$RP_URL\"." >&2
        continue
      fi

      ln -sf $RP_URL/$INDEX $RP_DIR/$INDEX
      ln -sf $RP_URL/CHECKSUMS.md5 $RP_DIR/CHECKSUMS.md5
      ln -sf $RP_URL/CHECKSUMS.md5.asc $RP_DIR/CHECKSUMS.md5.asc

      if [ "$RP_TYPE" = "sb" ]; then
        ln -sf $RP_URL/TAGS.TXT $RP_DIR/TAGS.TXT
      fi
      ;;
    http | https | ftp)
      wget -t 0 -c -O $RP_DIR/$INDEX "$RP_PROTOCOL://$RP_URL/$INDEX"
      wget -t 0 -c -O $RP_DIR/CHECKSUMS.md5 "$RP_PROTOCOL://$RP_URL/CHECKSUMS.md5"
      wget -t 0 -c -O $RP_DIR/CHECKSUMS.md5.asc "$RP_PROTOCOL://$RP_URL/CHECKSUMS.md5.asc"
  
      if [ "$RP_TYPE" = "sb" ]; then
        wget -t 0 -c -O $RP_DIR/TAGS.TXT "$RP_PROTOCOL://$RP_URL/TAGS.TXT"
      fi
      ;;
  esac

  RP_DATA="$RP_TYPE:$RP_NAME:$RP_PROTOCOL:$RP_SERVER:$RP_ADDRESS"
  awk -v RP_DATA="$RP_DATA" \
      -v CHECKSUMS="$RP_DIR/CHECKSUMS.md5" \
      -f $LIBEXEC/fmtindex.awk $RP_DIR/$INDEX >> $PM_WD/index.dat
done < $PM_WD/repos.dat

unset IFS

rm -rf $PM_TMPDIR

echo "Done."