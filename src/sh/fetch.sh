#!/bin/sh
#
# Copyright (c) 2019 Valery Timiriliyev timiriliyev@gmail.com
# 
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#

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
