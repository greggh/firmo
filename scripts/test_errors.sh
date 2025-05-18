#/bin/bash
# This script runs all tests in the tests directory and
# displays only the errors.
# It is intended to be run from the root of the repository.
# usage: ./scripts/test_errors.sh

# run the tests and pass all arguments to the command

lua firmo.lua "$@" | rg --color=always "^Running.*|.*ERROR.*|.*DEBUG.*|.*TRACE.*|.*WARN.*|.*FATAL.*"
