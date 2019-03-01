#!/bin/sh

rm -rf /tmp/pkutils-test
mkdir -p /tmp/pkutils-test
cd /tmp/pkutils-test

mkdir -p ./fake/var/lib/pkutils
mkdir -p ./fake/var/cache/pkutils
mkdir -p ./fake/etc/pkutils

cat <<EOF > ./fake/etc/pkutils/pkutils.conf
wget_args = '--quiet --show-progress'
use_deps = yes
EOF

cat <<EOF > ./test.awk
@include "pkutils.deps.awk"

BEGIN {
    pk_setup_dirs("./fake");
    db_rebuild();
    p = db_get_by_name(PACKAGENAME);
    pk_make_dependency_list(p, dlist);
    for (i = 1; i <= dlist["length"]; i++) {
        printf DB[dlist[i]]["name"] " ";
    }
    printf("\n");
}
EOF

# Sluceai 1.: net zavisimostei

cat <<EOF > ./fake/var/lib/pkutils/index.dat
test:.:.:app:2.22.1:i586:1:tt:tlz:00000000000000000000000000000000:Sample app:::
EOF

gawk -v PACKAGENAME=app -f "./test.awk" > ./result.txt 2> /dev/null
echo -e "[1]: \c"
if [ "$(cat ./result.txt)" = "app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat ./result.txt)\" instead of \"app \"."
    exit 1
fi

# Sluceai 2.: esth odna zavisimosth

cat <<EOF > ./fake/var/lib/pkutils/index.dat
test:.:.:app:2.22.1:i586:1:tt:tlz:00000000000000000000000000000000:Sample app:libbeta::
test:.:.:libbeta:0.68.3:i586:1:tt:tlz:00000000000000000000000000000000:Beta lib:::
EOF

gawk -v PACKAGENAME=app -f "./test.awk" > ./result.txt 2> /dev/null
echo -e "[2]: \c"
if [ "$(cat ./result.txt)" = "libbeta app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat ./result.txt)\" instead of \"libbeta app \"."
    exit 1
fi

# Sluceai 3.: esth dve zavisimosti

cat <<EOF > ./fake/var/lib/pkutils/index.dat
test:.:.:app:2.22.1:i586:1:tt:tlz:00000000000000000000000000000000:Sample app:libbeta,libsuck::
test:.:.:libbeta:0.68.3:i586:1:tt:tlz:00000000000000000000000000000000:Beta test:::
test:.:.:libsuck:14.88.5:i586:4:tt:tlz:00000000000000000000000000000000:Suck my lib:::
EOF

gawk -v PACKAGENAME=app -f "./test.awk" > ./result.txt 2> /dev/null
echo -e "[3]: \c"
if [ "$(cat ./result.txt)" = "libbeta libsuck app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat ./result.txt)\" instead of \"libbeta libsuck app \"."
    exit 1
fi

# Sluceai 4.: cyclicescaya zavisimosth

cat <<EOF > ./fake/var/lib/pkutils/index.dat
test:.:.:app:2.22.1:i586:1:tt:tlz:00000000000000000000000000000000:Sample app:libbeta,libsuck::
test:.:.:libbeta:0.68.3:i586:1:tt:tlz:00000000000000000000000000000000:Beta test:::
test:.:.:libsuck:14.88.5:i586:4:tt:tlz:00000000000000000000000000000000:Suck my lib:app::
EOF

gawk -v PACKAGENAME=app -f "./test.awk" > ./result.txt 2> /dev/null
echo -e "[4]: \c"
if [ "$(cat ./result.txt)" = "libbeta libsuck app " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat ./result.txt)\" instead of \"libbeta libsuck app \"."
    exit 1
fi

# Sluceai 5.: glubocoe derevo zavisimostei

cat <<EOF > ./fake/var/lib/pkutils/index.dat
test:.:.:alpha:1.0.0:i586:1:tt:tlz:00000000000000000000000000000000::bravo::
test:.:.:bravo:2.0.0:i586:2:tt:tlz:00000000000000000000000000000000::charlie::
test:.:.:charlie:3.0.0:i586:3:tt:tlz:00000000000000000000000000000000::delta::
test:.:.:delta:4.0.0:i586:4:tt:tlz:00000000000000000000000000000000::echo::
test:.:.:echo:5.0.0:i586:5:tt:tlz:00000000000000000000000000000000::foxtrot,golf::
test:.:.:foxtrot:6.0.0:i586:6:tt:tlz:00000000000000000000000000000000::india::
test:.:.:golf:7.0.0:i586:7:tt:tlz:00000000000000000000000000000000::hotel::
test:.:.:hotel:8.0.0:i586:8:tt:tlz:00000000000000000000000000000000::::
test:.:.:india:9.0.0:i586:9:tt:tlz:00000000000000000000000000000000::::
EOF

gawk -v PACKAGENAME=alpha -f "./test.awk" > ./result.txt 2> /dev/null
echo -e "[5]: \c"
if [ "$(cat ./result.txt)" = "india foxtrot hotel golf echo delta charlie bravo alpha " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat ./result.txt)\" instead of \"india foxtrot hotel golf echo delta charlie bravo alpha \"."
    exit 1
fi

# Sluceai 6.: glubocoe derevo zavisimostei s zacyclivaniem

cat <<EOF > ./fake/var/lib/pkutils/index.dat
test:.:.:alpha:1.0.0:i586:1:tt:tlz:00000000000000000000000000000000::bravo::
test:.:.:bravo:2.0.0:i586:2:tt:tlz:00000000000000000000000000000000::charlie::
test:.:.:charlie:3.0.0:i586:3:tt:tlz:00000000000000000000000000000000::delta::
test:.:.:delta:4.0.0:i586:4:tt:tlz:00000000000000000000000000000000::echo::
test:.:.:echo:5.0.0:i586:5:tt:tlz:00000000000000000000000000000000::foxtrot,golf::
test:.:.:foxtrot:6.0.0:i586:6:tt:tlz:00000000000000000000000000000000::india::
test:.:.:golf:7.0.0:i586:7:tt:tlz:00000000000000000000000000000000::hotel::
test:.:.:hotel:8.0.0:i586:8:tt:tlz:00000000000000000000000000000000::::
test:.:.:india:9.0.0:i586:9:tt:tlz:00000000000000000000000000000000::bravo::
EOF

gawk -v PACKAGENAME=alpha -f "./test.awk" > ./result.txt 2> /dev/null
echo -e "[6]: \c"
if [ "$(cat ./result.txt)" = "india foxtrot hotel golf echo delta charlie bravo alpha " ]; then
    echo "PASSED!"
else
    echo "FAILED!"
    echo "Got \"$(cat ./result.txt)\" instead of \"india foxtrot hotel golf echo delta charlie bravo alpha \"."
    exit 1
fi
