#!/bin/bash
set -euo pipefail

swift build -c release
echo "Build complete: $(swift build -c release --show-bin-path)/Wane"
