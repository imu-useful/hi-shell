#!/bin/sh
# Run the tests: ./tests/run.sh   (needs python3 and node; the matugen tests are skipped without matugen)
cd "$(dirname "$0")" && exec python3 -m unittest discover -s . -v "$@"
