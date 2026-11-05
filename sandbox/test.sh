#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/calc.sh"
[ "$(add 2 3)" = 5 ] || { echo "add failed"; exit 1; }
[ "$(sub 5 3)" = 2 ] || { echo "sub failed: got $(sub 5 3)"; exit 1; }
echo ok
