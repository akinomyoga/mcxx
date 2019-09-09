#!/bin/bash
# to be sourced from mcxx/cxx_pref.sh

# include guard
declare -f msc.initialized &>/dev/null && return
function msc.initialized { echo; }

function msc/is_cygwin {
  [[ -x /usr/bin/cygwin1.dll ]]
}
function msc/ends_with () {
  [[ $1 == *"$2" ]]
}
function msc/ends_with_icase () {
  local text="$(echo $1|tr '[A-Z]' '[a-z]')"
  [[ $text == *"$2" ]]
}

function msc.detect-compilers/search-in-program-files {
  local uProg=$1
  local version
  for version in 9.0 10.0 11.0 12.0 14.0; do
    local cl="$uProg/Microsoft Visual Studio $version/VC/bin/cl"
    [[ -x $cl ]] && COMPILERS+=("$cl:$cl")
  done

  for version in 2017; do
    local edition flag_found=
    for edition in Enterprise Professional Community; do
      local clpaths=$(printf '%s\n' "$uProg/Microsoft Visual Studio/$version/$edition"/VC/Tools/MSVC/*/bin/HostX86/x86/cl.exe | sort -r)
      IFS=$'\n' eval 'clpaths=($clpaths)'

      local cl
      for cl in "${clpaths[@]}"; do
        if [[ -x $cl ]]; then
          COMPILERS+=("$cl:$cl")
          flag_found=1
          break
        fi
      done

      [[ $flag_found ]] && break
    done
  done
}

function msc.detect-compilers {
  msc/is_cygwin || return

  # "C:\Program Files\"
  # "C:\Program Files (x86)\" in Win7
  local uProg="$(cygpath -u "$PROGRAMFILES" 2>/dev/null)" &&
    msc.detect-compilers/search-in-program-files "$uProg"

  # "C:\Program Files\" in Win7
  local uProg="$(cygpath -u "$PROGRAMW6432" 2>/dev/null)" &&
    msc.detect-compilers/search-in-program-files "$uProg"
}

# CXXDIR CXX; msc.create-config CXXDIR2
function msc.create-config {
  # check compiler
  msc/ends_with "${CXX%.exe}" cl || return 2
  echom 'compiler type = msc'

  local mshex_echox_prog='mcxx+prefix(msc.create-config)'
  local CXXDIR2="${1%/}"
  if [[ ! -d $CXXDIR2 ]]; then
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

  local CXX="${CXX%.exe}" rex
  local VSDIR=
  local MCXX_VCFULLVER=14.10.25017 # for VS 2017 Community
  if local rex='^(.*)/VC/Tools/MSVC/([0-9.]+)/bin/HostX86/x86/cl'; [[ $CXX =~ $rex ]]; then
    VSDIR="${BASH_REMATCH[1]}"
    MCXX_VCFULLVER="${BASH_REMATCH[2]}"
  elif msc/ends_with_icase "$CXX" /vc/bin/cl; then
    VSDIR="${CXX:0:$((${#CXX}-10))}"
  else
    echom "CXX='$CXX'"
    echoe 'failed to determine "Microsoft Visual Studio" directory.'
    return 1
  fi

  local VersionNumber= VisualStudioVersion=
  if [[ $VSDIR =~ /2017/(Community|Professional|Enterprise)$ ]]; then
    VisualStudioVersion=15.0
    VersionNumber=19.10 # VS 2017
  elif msc/ends_with "$VSDIR" 14.0; then
    VisualStudioVersion=14.0
    VersionNumber=19 # VS 2015
  elif msc/ends_with "$VSDIR" 12.0; then
    VisualStudioVersion=12.0
    VersionNumber=18 # VS 2013
  elif msc/ends_with "$VSDIR" 11.0; then
    VisualStudioVersion=11.0
    VersionNumber=17 # VS 2012
  elif msc/ends_with "$VSDIR" 10.0; then
    VisualStudioVersion=10.0
    VersionNumber=16 # VS 2010
  elif msc/ends_with "$VSDIR" 9.0; then
    VisualStudioVersion=9.0
    VersionNumber=15 # VS 2008
  # elif msc/ends_with "$VSDIR" 8.0; then
  #   VersionNumber=14 # VS 2005
  else
    echom "VSDIR='$VSDIR'"
    echoe 'failed to determine "Microsoft Visual Studio" directory.'
    return 1
  fi

  local PFDIR="${VSDIR%/*}"
  if [[ $VSDIR == "$PFDIR" ]]; then
    echom "VSDIR='$VSDIR'"
    echoe 'failed to determine "Microsoft Visual Studio" directory.'
    return 1
  fi

  #----------------------------------------------------------------------------

  local wPDIR="$PROGRAMFILES"
  local wWDIR="$WINDIR"
  local uPDIR="$(cygpath -u "$wPDIR")"
  local uWDIR="$(cygpath -u "$wWDIR")"
  local uVSDIR="$VSDIR"
  local wVSDIR="$(cygpath -w "$VSDIR")"

  if [[ $VSDIR != "${uPDIR%/}"/* ]]; then
    echoe 'install directroy of "Microsoft Visual Studio" is different from standard "Program Files" directory.'
    return 1
  fi

  local fname_config_template=$CXXDIR/share/adapter/msc/config.template.src
  if local cand= && [[ -s ${cand:=$CXXDIR/share/adapter/msc/msc$VersionNumber-config.src} ]]; then
    fname_config_template=$cand
  fi

  local bs='\'
  local wPDIR_escaped="${wPDIR//$bs$bs/$bs$bs}"
  local wWDIR_escaped="${wWDIR//$bs$bs/$bs$bs}"
  local wVSDIR_escaped="${wVSDIR//$bs$bs/$bs$bs}"
  sed "
    s/%%VisualStudioVersion%%/$VisualStudioVersion/
    s|%%wPDIR%%|$wPDIR_escaped|
    s|%%wWDIR%%|$wWDIR_escaped|
    s|%%uPDIR%%|$uPDIR|
    s|%%uWDIR%%|$uWDIR|
    s|%%uVSDIR%%|$uVSDIR|
    s|%%wVSDIR%%|$wVSDIR_escaped|
    s|%%MCXX_VCFULLVER%%|$MCXX_VCFULLVER|
  " "$fname_config_template" > "$CXXDIR2/config.src"

  [[ -f $CXXDIR2/cxxar ]] && /bin/rm "$CXXDIR2/cxxar"
  ln -sr "$CXXDIR/share/adapter/msc/cxxar.sh" "$CXXDIR2/cxxar"
}
