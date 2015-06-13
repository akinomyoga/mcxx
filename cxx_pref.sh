#!/bin/bash

: ${MWGDIR:=$HOME/.mwg}
: ${CXXDIR:=$MWGDIR/mcxx}
#source $MWGDIR/echox
source "$CXXDIR/ext/echox" --color=auto
mwg_echox_prog="mcxx($CXXDIR) +prefix"

mkd () { test -d "$1" || mkdir -p "$1"; }
ends_with () { test "${1%$2}" != "$1"; }
is_windows() { test -n "$SYSTEMROOT" -a -n "$PROGRAMFILES"; }

dirpref="$CXXDIR/local/prefix"
mkd "$dirpref"

#==============================================================================
#  cxx +prefix add
#  cxx +prefix auto
#------------------------------------------------------------------------------

generate_cxxprefix () {
  export CXX
  ret=$(

    # check if it is vc
    if [[ "$CXX" =~ "/Microsoft Visual Studio ([1-9][.0-9]*)/VC/bin/cl"(.exe)?$ ]]; then
      case "${BASH_REMATCH[1]}" in
      (9.0)  echo -n i686-win-vc-msc15 ; exit ;;
      (10.0) echo -n i686-win-vc-msc16 ; exit ;;
      esac
    fi

    "$CXX" --version 2>&1 |gawk '
      BEGIN{
        plat=ENVIRON["PLATFORM"];
        sub(/pc-cygwin/,"cygwin",plat);
      }
      /^[^[:space:]]+ \([^\)]*\) ([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)/{
        if(match($0,/[^[:space:]]+ \(([^\)]*)\) ([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)/,dict)>0){
          if(dict[1] ~ /^GCC\y/)
            gcc="gcc";
          else if(dict[1] ~ /^ICC\y/)
            gcc="icc";
          else if(dict[1] ~ /(^(TDM|tdm)\y)|\yMinGW-builds\y/){
            sub(/\ycygwin\y/,"win",plat);
            gcc="mingw";
          }else
            gcc=""

          if(gcc!=""){
            printf("%s-%s-%d.%d.%d",plat,gcc,dict[2],dict[3],dict[4]);
            comp++;
            exit;
          }
        }
      }
      /Microsoft ?\(R\) 32-bit C\/C\+\+ Optimizing Compiler Version/{
        if(match($0,/Version ([[:digit:]]+)\.([[:digit:]]+)/,dict)>0){
          printf("i686-win-vc-msc%d",dict[1]);
          comp++;
          exit;
        }
      }
      /^clang version ([[:digit:]]+)\.([[:digit:]]+)/{
        if(match($0,/^clang version ([[:digit:]]+)\.([[:digit:]]+)/,dict)>0){
          printf("%s-clang-%d.%d",plat,dict[1],dict[2]);
          comp++;
          exit;
        }
      }
      END{
        if(comp==0){
          CXX=ENVIRON["CXX"];
          sub(/^.+\//,"",CXX);
          sub(/\.exe$/,"",CXX);
          printf("%s-%s",plat,CXX);
        }
      }
    '
  )

  if is_windows && test -z "${ret##*-cygwin-gcc-*}"; then
    # test if it is mingw

    local ftmp="$(cygpath -w $CXXDIR/tmp.o)"
    if cat <<EOF | "$CXX" -xc - -c -o$ftmp &>/dev/null; then
#ifndef __MINGW32__
__choke__
#endif
EOF
      ret="${ret/-cygwin-gcc-/-win-mingw-}"
    fi
    rm -f "$ftmp"
  fi

  echo $ret
}

declare -a adapters=()
function adapters.initialize {
  ((${#adapters[@]})) && return
  
  # gcc は default でもあるので最後にする必要がある。
  adapters=(msc mingw gcc)

  local adp
  for adp in "${adapters[@]}"; do
    # ※全て source した後に中の関数を実行する必要がある。
    #   内部で互いに関数などを融通している為。
    source "$CXXDIR/share/adapter/$adp/prefix.sh"
  done
}

function cmd.prefix/add {
  local mwg_echox_prog='mcxx +prefix add'

  local a_quiet=''
  local a_default=''
  while test $# -gt 0 -a "x${1:0:1}" == "x-"; do
    case "$1" in
    -q)
      a_quiet=1 ;;
    -d)
      a_default=1 ;;
    *)
      echoe "unknown argument '$1'"
      return 1 ;;
    esac
    shift
  done

  #----------------------------------------------------------------------------
  # Read settings
  #----------------------------------------------------------------------------
  if test -z "$CXX" -o -z "$CC"; then
    test -z "$CXX" && echoe "environmental variable CXX is not set"
    test -z "$CC" && echoe "environmental variable CC is not set"
    return 1
  fi

  local name="${1:-${CXX##*/}}"
  echom "adding compiler: [35m$name[m ($CXX)"
  echox_push
  echom "CXX=$CXX"
  echom "CC=$CC"

  #----------------------------------------------------------------------------
  # Determine CXXKEY and CXXPREFIX
  #----------------------------------------------------------------------------
  PLATFORM.initialize

  prefix="$(generate_cxxprefix)"
  default_prefix="$prefix"
  i=1; while test -s "$dirpref/prefix+$prefix.stamp"; do
    prefix="$default_prefix+$((i++))"
  done
  if test -z "$a_quiet"; then
    while echor prefix "CXXPREFIX=" "$prefix";do
      test ! -s "$dirpref/prefix+$prefix.stamp" && break
      echoe "specified cxxprefix is already used!"
    done
  fi

  # read key
  local key=1
  while test -s "$dirpref/key+$key.stamp"; do
    let key++
  done
  if test -z "$a_quiet"; then
    while echor key "CXXKEY=" "$key";do
      test ! -s "$dirpref/key+$key.stamp" && break
      echoe "specified cxxkey is already used!"
    done
  fi

  #----------------------------------------------------------------------------
  # Confirm
  #----------------------------------------------------------------------------
  # kakunin
  echox_push
  echom "CXXPREFIX=$prefix"
  echom "CXXKEY=$key"
  echom "CXX=$CXX"
  echom "CC=$CC"
  echox_pop
  if test -z "$a_quiet"; then
    while :;do
      echor result "would you like to add the above setting (y/n)"
      if test "$result" == 'y'; then
        break
      elif test "$result" == 'n'; then
        echox_pop
        return
      fi
    done
  fi

  #----------------------------------------------------------------------------
  # Write settings
  #----------------------------------------------------------------------------
  # CXXDIR/local/prefix
  mkd "$dirpref"
  echo -n "$prefix" > "$dirpref/key+$key.stamp"
  echo -n "$key" > "$dirpref/prefix+$prefix.stamp"
  if test -n "$a_default"; then
    local key_default_file="$dirpref/key+default.stamp"
    test -e "$key_default_file" && rm -f "$key_default_file"
    ln -s "key+$key.stamp" "$key_default_file"
  fi

  # CXXDIR/local/m
  test ! -d "$CXXDIR/local/m" && cp -pr "$CXXDIR/share/m.new" "$CXXDIR/local/m"

  local cxxdir2="$CXXDIR/local/m/$prefix"
  mkd "$cxxdir2"

  adapters.initialize

  local adp r=0 CXXPREFIX="$prefix"
  for adp in "${adapters[@]}"; do
    # 関数 $adp.create-config
    #   $adp.create-config CXXDIR2
    # \env   [in]  CXXDIR    mcxx インストールディレクトリを指定します。
    # \env   [in]  CXXPREFIX 設定の名称を指定します。
    # \env   [in]  CXX       使用する C++ コンパイラを指定します。
    # \env   [in]  CC        使用する C コンパイラを指定します。
    # \param [in]  CXXDIR2   構成情報を初期化するディレクトリを指定します。
    # \return[out] ?         終了状態を返します。
    #   0 = 正常終了
    #   1 = 構成情報の初期化に失敗
    #   2 = この adp で担当するコンパイラではない

    "$adp.create-config" "$cxxdir2"; r=$?
    ((r==2)) && continue

    # when error has occured
    ((r)) && echoe "failed to generate the config directory $cxxdir2"

    break
  done

  echox_pop

  return $r
}

function PLATFORM.initialize {
  if test -z "$PLATFORM"; then
    export PLATFORM="$(source $CXXDIR/cxx_pref-guess.src)"
  fi
}

function cmd.prefix/auto () {
  PLATFORM.initialize
  adapters.initialize

  # COMPILERS
  #   一番先頭に来るのが default になるので順番は重要
  local -a COMPILERS=()
  gcc.detect-compilers
  msc.detect-compilers
  
  local line fields
  for line in "${COMPILERS[@]}"; do
    IFS=: eval 'fields=($line)'
    local CXX="${fields[0]}"
    local CC="${fields[1]}"
    cmd.prefix/add "$@"

    if test ! -e "$dirpref/key+default.stamp"; then
      # default として登録
      local prefs=("$dirpref"/prefix+*.stamp)
      local pref0="${prefs[0]}"
      pref0="${pref0##*/prefix+}"
      pref0="${pref0%.stamp}"
      if test -n "$pref0" -a "$pref0" != '*'; then
        cmd.prefix/set-default "$pref0"
      fi
    fi
  done
}

#==============================================================================
#  cxx +prefix remove
#  cxx +prefix set-default
#  cxx +prefix set-key
#------------------------------------------------------------------------------

function get_cxxpair_fromKeyOrPrefix {
  local arg1="$1"

  CXXKEY= CXXPREFIX=
  if test -f "$dirpref/key+$1.stamp"; then
    CXXKEY="$1"
    CXXPREFIX=$(cat "$dirpref/key+$CXXKEY.stamp" 2>&1)
    if test "$CXXKEY" == default; then
      CXXKEY=$(cat "$dirpref/prefix+$CXXPREFIX.stamp" 2>&1)
    fi
  elif test -f "$dirpref/prefix+$1.stamp"; then
    CXXPREFIX="$1"
    CXXKEY=$(cat "$dirpref/prefix+$CXXPREFIX.stamp" 2>&1)
  fi

  if test -z "$CXXKEY" -o -z "$CXXPREFIX"; then
    echoe "the specified key/prefix '$arg1' is invalid!"
    return 1
  fi
}

cmd.prefix/remove() {
  local mwg_echox_prog='mcxx +prefix remove'

  # check argument $1
  if test -z "$1"; then
    echoe "key nor prefix is specified"
    echoi "usage: cxx mwg prefix remove <key/prefix>"
    return 1
  elif test "$1" == default; then
    echoe "default key cannot be removed!"
    return 1
  fi

  local CXXKEY= CXXPREFIX=
  get_cxxpair_fromKeyOrPrefix "$1" || return 1

  # check if the prefix is not the default prefix.
  if test -f "$dirpref/key+default.stamp"; then
    local DEFPREFIX=$(cat "$dirpref/key+default.stamp")
    if test "$CXXPREFIX" == "$DEFPREFIX"; then
      echoe "default setting, $CXXKEY ($CXXPREFIX), cannot be removed!"
      return 1
    fi
  fi

  while :;do
    echor result "would you like to remove the settings for $CXXKEY ($CXXPREFIX) (y/n)"
    if test "$result" == 'y'; then
      break
    elif test "$result" == 'n'; then
      return
    fi
  done

  rm -f "$dirpref/key+$CXXKEY.stamp"
  rm -f "$dirpref/prefix+$CXXPREFIX.stamp"
}

cmd.prefix/set-default() {
  local mwg_echox_prog='mcxx +prefix set-default'

  # check argument $1
  if test -z "$1"; then
    echoe "key nor prefix is specified"
    echom "usage: mcxx mwg prefix set-default <key/prefix>"
    return 1
  elif test "$1" == default; then
    echoe "default key cannot be set as default!"
    return 1
  fi

  local CXXKEY= CXXPREFIX=
  get_cxxpair_fromKeyOrPrefix "$1" || return 1

  local fstamp_default="$dirpref/key+default.stamp"
  if test -f "$fstamp_default"; then
    # check if the prefix is not yet the default prefix.
    local DEFPREFIX=$(cat "$fstamp_default")
    if test "$CXXPREFIX" == "$DEFPREFIX"; then
      echoe "the setting, $CXXKEY ($CXXPREFIX), is already default!"
      return 1
    fi

    rm "$fstamp_default"
  elif test -h "$fstamp_default"; then
    # dangling symbolic link
    rm "$fstamp_default"
  fi

  ln -s "key+$CXXKEY.stamp" "$fstamp_default"
}

function cmd.prefix/set-key {
  local mwg_echox_prog='mcxx +prefix set-key'

  if test -z "$1"; then
    echoe "a key nor a prefix is specified"
    echom "usage: mcxx mwg prefix set-key <oldkey/prefix> newkey"
    return 1
  elif test -z "$2"; then
    echoe "a new key is not specified"
    echom "usage: mcxx mwg prefix set-key <oldkey/prefix> newkey"
    return 1
  elif test -f "$dirpref/key+$2.stamp"; then
    echoe "the specified new key '$2' is already used"
    return 1
  fi

  local CXXKEY= CXXPREFIX=
  get_cxxpair_fromKeyOrPrefix "$1" || return 1

  # check if is default setting
  local fkdef="$dirpref/key+default.stamp"
  if test -f "$fkdef"; then
    if test "$CXXPREFIX" == "$(cat "$fkdef")"; then
      local is_default=1
    fi
  fi

  local NEWKEY="$2"

  mv "$dirpref/key+$CXXKEY.stamp" "$dirpref/key+$NEWKEY.stamp"
  echo -n "$NEWKEY" > "$dirpref/prefix+$CXXPREFIX.stamp"

  if test -n "$is_default"; then
    cmd.prefix/set-default "$NEWKEY"
  fi
}

#==============================================================================
#  get_cxxprefix
#------------------------------------------------------------------------------

get_cxxprefix() {
  source "$CXXDIR/cxx_pref-get.sh"
  echo -n "$CXXPREFIX"
}

show_cxxprefix_nocache() {
  local fstamp_default="$dirpref/key+default.stamp"
  if test -f "$fstamp_default"; then
    local DEFPREFIX=$(cat "$fstamp_default")
  fi

  for pref in "$dirpref"/prefix+*.stamp; do
    local prefix="${pref#$dirpref/prefix+}"; prefix="${prefix%.stamp}"
    local key="$(cat "$pref")"

    local flag=' '
    test "$prefix" == "$DEFPREFIX" && flag='*'

    printf "%s %-10s %s\n" "$flag" "$key" "$prefix"
  done
}

show_cxxprefix() {
  local cache="$dirpref/show_cxxprefix.cache"
  local pref
  for pref in "$dirpref" "$dirpref"/{prefix,key}+*.stamp; do
    if test -e "$pref" -a "$cache" -ot "$pref"; then
      show_cxxprefix_nocache | tee "$cache"
      return
    fi
  done
  cat "$cache"
}

function cmd.prefix/help {
  source "$CXXDIR/ext/mydoc1" <<"EOF"
usage: cxx +prefix [_operation_] [[_arguments_]...]

Operations:

.[*help*]
..shows this help.

.[*auto*]
..automatically searches and registers compilers in the system

.[*add*]
..manually adds settings to use the specified compiler.
..the compilers are specified through the environmental variables [C[CC]] and [C[CXX]].
..[C[CC]] specifies the c compiler and [C[CXX]] specifies the c++ compiler.

.[*remove*] [_key/prefix_]
..removes the settings of the specified compiler

.[*set-default*] [_key/prefix_]
..sets the specified setting to the default setting.

.[*set-key*] [_key/prefix_] [_newkey_]
..resets the key for the specified settings.

.[*list*]
..prints the list of registered compilers

.[*get*]
..prints the [C[CXXPREFIX]] of the current settings

.[*dbg-generate_cxxprefix*] (for internal use)

EOF
}

case "x$1" in
(xlist)
  show_cxxprefix ;;
(xget)
  get_cxxprefix ;;
(xdbg-generate_cxxprefix)
  PLATFORM.initialize
  generate_cxxprefix ;;
(xremove)
  shift
  cmd.prefix/remove "$@"
  ;;
(xset-default)
  shift
  cmd.prefix/set-default "$@"
  ;;
(*)
  declare cmd="cmd.prefix/$1"
  if declare -f "$cmd" &>/dev/null; then
    shift
    "$cmd" "$@"
  else
    echom "usage: $0 list|auto|add|get|set-default|remove|set-key|dbg-generate_cxxprefix"
  fi ;;
esac
