#!/bin/bash

version=2.1
: ${MWGDIR:=$HOME/.mwg}

function echo-eval {
  eval "echo \"$@\""
  eval "$@"
}

if test "$PWD" != "$MWGDIR/mcxx"; then
  echo-eval 'mkdir -p "$MWGDIR/mcxx"'
  echo-eval 'cp -r ./* "$MWGDIR/mcxx/"'
fi

function ln_versioned {
  local fpath_src="$MWGDIR/mcxx/$1"
  local fname_dst="${2:-$1}"
  local fname_ver="${2:-$1}-$version"
  local fpath_dst="$MWGDIR/bin/$fname_dst"
  local fpath_ver="$MWGDIR/bin/$fname_ver"

  # .mwg/hoge-version
  echo-eval 'ln -sf "$fpath_src" "$fpath_ver"'

  # .mwg/hoge
  if [[ ! -f $fpath_dst || $fpath_dst -ot $fpath_src ]]; then
    echo-eval 'ln -sf "$fname_ver" "$fpath_dst"'
  fi
}

mkdir -p "$MWGDIR/bin"
ln_versioned cxx   mcxx
ln_versioned cxx   mcc
ln_versioned cxxar mcxxar
type cxx   &>/dev/null || ln_versioned cxx   cxx
type cc    &>/dev/null || ln_versioned cxx   cc
type cxxar &>/dev/null || ln_versioned cxxar cxxar

if [[ ! -f $MWGDIR/mcxx/local/prefix/key+default.stamp ]]; then
  "$MWGDIR/mcxx/cxx" +prefix auto
fi
