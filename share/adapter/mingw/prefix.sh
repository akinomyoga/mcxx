#!/bin/bash
# to be sourced from mcxx/cxx_pref.sh

# include guard
declare -f mingw.initialized &>/dev/null && return
function mingw.initialized { echo; }

# include gcc/prefix.sh for gcc/generate_cxxstdspec

function mingw/is_cygwin {
  test -x /usr/bin/cygwin1.dll
}

# function mingw.detect-compilers {
#   mingw/is_cygwin || return

#   local uProg="$(cygpath -u "$PROGRAMFILES")"

#   local cl="$uProg/Microsoft Visual Studio 9.0/VC/bin/cl"
#   test -x "$cl" && echo "$cl"

#   local cl="$uProg/Microsoft Visual Studio 10.0/VC/bin/cl"
#   test -x "$cl" && echo "$cl"
# }

function mingw.create-config {
  # check compiler
  mingw/is_cygwin && [[ "$CXXPREFIX" =~ -mingw- ]] || return 2
  echom 'compiler type = mingw'

  local mshex_echox_prog='mcxx+prefix(mingw.create-config)'
  local CXXDIR2="${1%/}"
  if test ! -d "$CXXDIR2"; then
    echoe 'specified directory does not exist'
    echom "usage $0 \$CXXDIR/local/m/\$CXXPREFIX"
    return 1
  fi

  # cxx_name
  local cxx_name=${CXX##*/}
  cxx_name="${cxx_name%.exe}"
  local cc_name=${CC##*/}
  cc_name="${cc_name%.exe}"

  # cxx_stdspec
  local cxx_stdspec
  gcc/generate_cxxstdspec -v cxx_stdspec "$CXXPREFIX"

  # config.src
  local uPREFIX="${CXX%/*}"; uPREFIX="${CXX%/bin}"
  local wPREFIX="$(cygpath -w "$uPREFIX")"
  local triplet=("$uPREFIX/lib/gcc/"*) ; triplet="${triplet##*/}"
  cat <<EOF >"$CXXDIR2/config.src"
# -*- mode:sh -*-

# export PATH="\$PATH"

function mcxx.config.init_paths {
  local version=${CXXPREFIX##*-}
  local triplet='$triplet'
  local uPREFIX='$uPREFIX'
  local wPREFIX='$wPREFIX'

  export PATH="$uPREFIX/bin:$uPREFIX/$triplet/bin:$uPREFIX/libexec/gcc/$triplet/$version:$PATH"

  export C_INCLUDE_PATH="$wPREFIX/include"
  export CPLUS_INCLUDE_PATH="$wPREFIX/include;$wPREFIX/lib/gcc/$triplet/$version/include"
  export LIBRARY_PATH="$wPREFIX/lib;$wPREFIX/lib/gcc/$triplet/$version"
}
mcxx.config.init_paths

source_if() { test -e "\$1" && source "\$@" >/dev/null; }
source_if "\${CXXDIR:-\$HOME/.mwg/mcxx}/local/m/common.src" mingw

if test "x\$1" == xcxx; then
  CXX='$CXX$cxx_stdspec'
  CC='$CC'
elif test "x\$1" == xenv; then
  # alias $cxx_name="$CXX \$FLAGS \$CXXFLAGS$cxx_stdspec"
  # alias $cc_name="$CC \$FLAGS \$CFLAGS"
  alias $cxx_name='$CXX -finput-charset=CP932 -fexec-charset=CP932$cxx_stdspec'
  alias $cc_name='$CC -finput-charset=CP932 -fexec-charset=CP932'
  echo '.... setup $CXXPREFIX'
fi
EOF

  ln -s "$CXXDIR/share/adapter/mingw/cxxar.sh" "$CXXDIR2/cxxar"
}
