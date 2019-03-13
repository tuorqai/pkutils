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

death() {
  rm -rf $TMP
}
trap death EXIT

TMP=$(mktemp -p /tmp -d pktest.XXXXXX 2>/dev/null)
if [ $? -ne 0 ]; then
    TMP="/tmp/pktest.${RANDOM}"
    mkdir -m 0700 $TMP || exit 255
fi

export AWKPATH="$(pwd)/../src/awk"
export PKUTILS_LIBEXEC="$(pwd)/../src/sh"

cat <<EOF > $TMP/test.awk
@include "pkutils.version-compare.awk"

BEGIN {
    status = compare_versions(ARGV[1], ARGV[2]);
    if (status >= 0) {
        print ARGV[1];
    } else {
        print ARGV[2];
    }
}
EOF

# Test #1

echo -e "[243 vs 240]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "243" "240")
if [ "$RESULT" == "243" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #1.1

echo -e "[240 vs 243]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "240" "243")
if [ "$RESULT" == "243" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #2

echo -e "[4.9 vs 5.0]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "4.9" "5.0")
if [ "$RESULT" == "5.0" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #3

echo -e "[5.11 vs 5.10]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "5.11" "5.10")
if [ "$RESULT" == "5.11" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #4

echo -e "[0.21 vs 1.21]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "0.21" "1.21")
if [ "$RESULT" == "1.21" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #5

echo -e "[9.10.8_P1 vs 9.10.4_P1]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "9.10.8_P1" "9.10.4_P1")
if [ "$RESULT" == "9.10.8_P1" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #6

echo -e "[19961115 vs 20040517]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "19961115" "20040517")
if [ "$RESULT" == "20040517" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #6

echo -e "[20190215 vs 20190213]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "20190215" "20190213")
if [ "$RESULT" == "20190215" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #7

echo -e "[1.0.0.1 vs 1.0.0]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "1.0.0.1" "1.0.0")
if [ "$RESULT" == "1.0.0.1" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #8

echo -e "[20190215git vs 20190215]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "20190215git" "20190215")
if [ "$RESULT" == "20190215git" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi

# Test #8.1

echo -e "[20190215 vs 20190215git]... \c"
RESULT=$(gawk -f "${TMP}/test.awk" -- "20190215" "20190215git")
if [ "$RESULT" == "20190215git" ]; then
    echo "PASSED!"
else
    echo "FAILED! GOT $RESULT"
fi
