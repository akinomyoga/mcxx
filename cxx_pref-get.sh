#!/bin/bash

test -f .cxxkey && export CXXKEY="$(cat .cxxkey)"

dirpref="$CXXDIR/local/prefix"

if test -s "$dirpref/key+$CXXKEY.stamp"; then
  export CXXPREFIX="$(cat "$dirpref/key+$CXXKEY.stamp")"
elif test -s "$dirpref/key+default.stamp"; then
  export CXXPREFIX="$(cat "$dirpref/key+default.stamp")"
else
  echo "unrecognized CXXKEY '$CXXKEY'" >/dev/stderr
  exit 1
fi

export CXXDIR2="$CXXDIR/local/m/$CXXPREFIX"
