#!/bin/sh

VERSION=${VERSION:-0.2.1}

set -e

mkdir -p ./pkutils-$VERSION
cp -Rv ../src ./pkutils-$VERSION
tar cJfv ./pkutils-$VERSION.tar.bz2 pkutils-$VERSION
rm -rf ./pkutils-$VERSION
