#!/bin/sh

# Environment:
# EXEC - path to executable (should be e.g. /usr/bin/wget)
# ARGS - arguments passed to the executable
# DRYRUN - don't actually execute the command, just print it to standard output

interrupt() {
  exit 200
}

trap interrupt SIGINT

# Let's rock

REMOTE="$1"

if [ "$DRYRUN" = "yes" ]; then
  echo ">> $EXEC $ARGS $REMOTE"
  exit 0
fi

$EXEC $ARGS $REMOTE
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  exit 1
fi
