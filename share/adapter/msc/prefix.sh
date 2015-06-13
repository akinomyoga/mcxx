#!/bin/bash
# to be sourced from mcxx/cxx_pref.sh

# include guard
declare -f msc.initialized &>/dev/null && return
function msc.initialized { echo; }

function msc/is_cygwin {
  test -x /usr/bin/cygwin1.dll
}
function msc/ends_with () {
  test "${1%$2}" != "$1"
}
function msc/ends_with_icase () {
  local text="$(echo $1|tr '[A-Z]' '[a-z]')"
  test "${text%$2}" != "$text"
}

function msc.detect-compilers {
  msc/is_cygwin || return

  local uProg uProg64

  if uProg="$(cygpath -u "$PROGRAMFILES" 2>/dev/null)"; then
    # C:\Program Files\
    # C:\Program Files (x86)\ in Win7

    local cl="$uProg/Microsoft Visual Studio 9.0/VC/bin/cl"
    test -x "$cl" && COMPILERS+=("$cl:$cl")

    local cl="$uProg/Microsoft Visual Studio 10.0/VC/bin/cl"
    test -x "$cl" && COMPILERS+=("$cl:$cl")
  fi

  if uProg64="$(cygpath -u "$PROGRAMW6432" 2>/dev/null)"; then
    # C:\Program Files\ in Win7

    local cl="$uProg64/Microsoft Visual Studio 9.0/VC/bin/cl"
    test -x "$cl" && COMPILERS+=("$cl:$cl")

    local cl="$uProg64/Microsoft Visual Studio 10.0/VC/bin/cl"
    test -x "$cl" && COMPILERS+=("$cl:$cl")
  fi
}

# CXXDIR CXX; msc.create-config CXXDIR2
function msc.create-config {
  # check compiler
  msc/ends_with "${CXX%.exe}" cl || return 2
  echom 'compiler type = msc'

  local mwg_echox_prog='mcxx+prefix(msc.create-config)'
  local CXXDIR2="${1%/}"
  if test ! -d "$CXXDIR2"; then
    echoe 'specified directory does not exist'
    echom "usage $0 \$CXXDIR/local/m/\$CXXPREFIX"
    return 1
  fi

  if ! msc/is_cygwin; then
    echoe 'current system is not cygwin.'
    return 1
  fi

  #----------------------------------------------------------------------------
  # Analyze Path CXX

  local CXX="${CXX%.exe}"
  if msc/ends_with_icase "$CXX" /vc/bin/cl; then
    local VSDIR="${CXX:0:$((${#CXX}-10))}"
  else
    echom "CXX='$CXX'"
    echoe 'failed to determine "Microsoft Visual Studio" directory.'
    return 1
  fi

  local VersionNumber
  if msc/ends_with "$VSDIR" 10.0; then
    VersionNumber=16 # VS 2010
  elif msc/ends_with "$VSDIR" 9.0; then
    VersionNumber=15 # VS 2008
  # elif msc/ends_with "$VSDIR" 8.0; then
  #   VersionNumber=14 # VS 2005
  else
    echom "VSDIR='$VSDIR'"
    echoe 'failed to determine "Microsoft Visual Studio" directory.'
    return 1
  fi

  local PFDIR="${VSDIR%/*}"
  if test "$VSDIR" == "$PFDIR"; then
    echom "VSDIR='$VSDIR'"
    echoe 'failed to determine "Microsoft Visual Studio" directory.'
    return 1
  fi

  #----------------------------------------------------------------------------

  local wPDIR="$PROGRAMFILES"
  local wWDIR="$WINDIR"
  local uPDIR="$(cygpath -u "$wPDIR")"
  local uWDIR="$(cygpath -u "$wWDIR")"

  if test "$uPDIR" != "$PFDIR"; then
    echoe 'install directroy of "Microsoft Visual Studio" is different from standard "Program Files" directory.'
    return 1
  fi

  local bs='\'
  local wPDIRr="${wPDIR//$bs$bs/$bs$bs}"
  local wWDIRr="${wWDIR//$bs$bs/$bs$bs}"
  sed "
    s|%%wPDIR%%|$wPDIRr|
    s|%%wWDIR%%|$wWDIRr|
    s|%%uPDIR%%|$uPDIR|
    s|%%uWDIR%%|$uWDIR|
  " "$CXXDIR/share/adapter/msc/msc$VersionNumber-config.src" > "$CXXDIR2/config.src"

  test -f "$CXXDIR2/cxxar" && /bin/rm "$CXXDIR2/cxxar"
  ln -s "$CXXDIR/share/adapter/msc/cxxar.sh" "$CXXDIR2/cxxar"
}
