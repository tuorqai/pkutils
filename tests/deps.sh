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

export FAKEROOT=$TMP/fake
export AWKPATH="$(pwd)/../src/awk"
export PKUTILS_LIBEXEC="$(pwd)/../src/sh"

mkdir -p $FAKEROOT/var/{lib,cache}/pkutils
mkdir -p $FAKEROOT/etc/pkutils

cat <<EOF > $FAKEROOT/etc/pkutils/pkutils.conf
wget_args = '--quiet --show-progress'
use_deps = yes
EOF

cat <<EOF > $TMP/test.awk
@include "pkutils.foundation.awk"
@include "pkutils.deps.awk"

BEGIN {
    pk_setup_dirs(ENVIRON["FAKEROOT"]);
    db_rebuild();
    p = db_get_by_name(PACKAGENAME);
    add_to_dependency_list(p, dlist, 0);
    for (i = 1; i <= dlist["length"]; i++) {
        printf DB[dlist[i]]["name"] " ";
    }
    printf("\n");
}
EOF

# Sluceai 1.: net zavisimostei

cat <<EOF > $FAKEROOT/var/lib/pkutils/index.dat
test,.,.,app,2.22.1,i586,1,tt,tlz,00000000000000000000000000000000,"Sample app",,,,,,,
EOF

gawk -v PACKAGENAME=app -f "$TMP/test.awk" > $TMP/result.txt 2> /dev/null
echo -e "[1]: \c"
if [ "$(cat $TMP/result.txt)" = "app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat $TMP/result.txt)\" instead of \"app \"."
    exit 1
fi

# Sluceai 2.: esth odna zavisimosth

cat <<EOF > $FAKEROOT/var/lib/pkutils/index.dat
test,.,.,app,2.22.1,i586,1,tt,tlz,00000000000000000000000000000000,"Sample app",libbeta,,,,,,
test,.,.,libbeta,0.68.3,i586,1,tt,tlz,00000000000000000000000000000000,"Beta lib",,,,,,,
EOF

gawk -v PACKAGENAME=app -f "$TMP/test.awk" > $TMP/result.txt 2> /dev/null
echo -e "[2]: \c"
if [ "$(cat $TMP/result.txt)" = "libbeta app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat $TMP/result.txt)\" instead of \"libbeta app \"."
    exit 1
fi

# Sluceai 3.: esth dve zavisimosti

cat <<EOF > $FAKEROOT/var/lib/pkutils/index.dat
test,.,.,app,2.22.1,i586,1,tt,tlz,00000000000000000000000000000000,"Sample app",libbeta libsuck,,,,,,
test,.,.,libbeta,0.68.3,i586,1,tt,tlz,00000000000000000000000000000000,"Beta test",,,,,,,
test,.,.,libsuck,14.88.5,i586,4,tt,tlz,00000000000000000000000000000000,"Suck my lib",,,,,,,
EOF

gawk -v PACKAGENAME=app -f "$TMP/test.awk" > $TMP/result.txt 2> /dev/null
echo -e "[3]: \c"
if [ "$(cat $TMP/result.txt)" = "libbeta libsuck app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat $TMP/result.txt)\" instead of \"libbeta libsuck app \"."
    exit 1
fi

# Sluceai 4.: cyclicescaya zavisimosth

cat <<EOF > $FAKEROOT/var/lib/pkutils/index.dat
test,.,.,app,2.22.1,i586,1,tt,tlz,00000000000000000000000000000000,"Sample app",libbeta libsuck,,,,,,
test,.,.,libbeta,0.68.3,i586,1,tt,tlz,00000000000000000000000000000000,"Beta test",,,,,,,
test,.,.,libsuck,14.88.5,i586,4,tt,tlz,00000000000000000000000000000000,"Suck my lib",app,,,,,,
EOF

gawk -v PACKAGENAME=app -f "$TMP/test.awk" > $TMP/result.txt 2> /dev/null
echo -e "[4]: \c"
if [ "$(cat $TMP/result.txt)" = "libbeta libsuck app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat $TMP/result.txt)\" instead of \"libbeta libsuck app \"."
    exit 1
fi

# Sluceai 5.: glubocoe derevo zavisimostei

cat <<EOF > $FAKEROOT/var/lib/pkutils/index.dat
test,.,.,alpha,1.0.0,i586,1,tt,tlz,00000000000000000000000000000000,,bravo,,,,,,
test,.,.,bravo,2.0.0,i586,2,tt,tlz,00000000000000000000000000000000,,charlie,,,,,,
test,.,.,charlie,3.0.0,i586,3,tt,tlz,00000000000000000000000000000000,,delta,,,,,,
test,.,.,delta,4.0.0,i586,4,tt,tlz,00000000000000000000000000000000,,echo,,,,,,
test,.,.,echo,5.0.0,i586,5,tt,tlz,00000000000000000000000000000000,,foxtrot golf,,,,,,
test,.,.,foxtrot,6.0.0,i586,6,tt,tlz,00000000000000000000000000000000,,india,,,,,,
test,.,.,golf,7.0.0,i586,7,tt,tlz,00000000000000000000000000000000,,hotel,,,,,,
test,.,.,hotel,8.0.0,i586,8,tt,tlz,00000000000000000000000000000000,,,,,,,,
test,.,.,india,9.0.0,i586,9,tt,tlz,00000000000000000000000000000000,,,,,,,,
EOF

gawk -v PACKAGENAME=alpha -f "$TMP/test.awk" > $TMP/result.txt 2> /dev/null
echo -e "[5]: \c"
if [ "$(cat $TMP/result.txt)" = "india foxtrot hotel golf echo delta charlie bravo alpha " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat $TMP/result.txt)\" instead of \"india foxtrot hotel golf echo delta charlie bravo alpha \"."
    exit 1
fi

# Sluceai 6.: glubocoe derevo zavisimostei s zacyclivaniem

cat <<EOF > $FAKEROOT/var/lib/pkutils/index.dat
test,.,.,alpha,1.0.0,i586,1,tt,tlz,00000000000000000000000000000000,,bravo,,,,,,
test,.,.,bravo,2.0.0,i586,2,tt,tlz,00000000000000000000000000000000,,charlie,,,,,,
test,.,.,charlie,3.0.0,i586,3,tt,tlz,00000000000000000000000000000000,,delta,,,,,,
test,.,.,delta,4.0.0,i586,4,tt,tlz,00000000000000000000000000000000,,echo,,,,,,
test,.,.,echo,5.0.0,i586,5,tt,tlz,00000000000000000000000000000000,,foxtrot golf,,,,,,
test,.,.,foxtrot,6.0.0,i586,6,tt,tlz,00000000000000000000000000000000,,india,,,,,,
test,.,.,golf,7.0.0,i586,7,tt,tlz,00000000000000000000000000000000,,hotel,,,,,,
test,.,.,hotel,8.0.0,i586,8,tt,tlz,00000000000000000000000000000000,,,,,,,,
test,.,.,india,9.0.0,i586,9,tt,tlz,00000000000000000000000000000000,,bravo,,,,,,
EOF

gawk -v PACKAGENAME=alpha -f "$TMP/test.awk" > $TMP/result.txt 2> /dev/null
echo -e "[6]: \c"
if [ "$(cat $TMP/result.txt)" = "india foxtrot hotel golf echo delta charlie bravo alpha " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat $TMP/result.txt)\" instead of \"india foxtrot hotel golf echo delta charlie bravo alpha \"."
    exit 1
fi
