#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
xcrun clang -fobjc-arc -Wall -O2 tests/drag-regression.m \
  -framework Cocoa -framework IOKit -framework ApplicationServices \
  -o build/drag-regression
./build/drag-regression
