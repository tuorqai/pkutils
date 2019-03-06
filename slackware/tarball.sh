#!/bin/sh

VERSION=${VERSION:-5.0m16}

set -e

mkdir -p ./pkutils-$VERSION

cp -Rv ../src ./pkutils-$VERSION
cp -Rv ../conf ./pkutils-$VERSION

tar cJfv ./pkutils-$VERSION.tar.bz2 pkutils-$VERSION

rm -rf ./pkutils-$VERSION
