#!/bin/sh
set -eu
cd "$(dirname "$0")"
xcrun swiftc -O main.swift -o ZedTabsHelper
./ZedTabsHelper --self-test
