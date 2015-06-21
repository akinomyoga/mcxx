#!/bin/bash

#ICONV=cat
#ICONV="iconv -c -f cp932 -t utf-8"
ICONV="nkf -w"

declare -a clargs
declare -a linkargs
add_arg () {
  while test $# -gt 0; do
    clargs[${#clargs[@]}]="$1"
    shift
  done
}
add_larg () {
  while test $# -gt 0; do
    linkargs[${#linkargs[@]}]="$1"
    shift
  done
}

declare first_inputfile
declare -a inputfiles
push_inputfile () {
  if test -z "$first_inputfile" -a -n "$1"; then
    first_inputfile="$1"
  fi
  inputfiles[${#inputfiles[*]}]="$1"
}

arg_output=""

declare -a tmpfiles
push_tmpfile () {
  tmpfiles[${#tmpfiles[*]}]="$1"
}

#------------------------------------------------------------------------------
add_incdir () {
  test -n "$1" && add_arg "-I$(cygpath -w "$1")"
}
add_libdir () {
  test -n "$1" && add_larg "/LIBPATH:$(cygpath -w "$1")"
}
add_define () {
  test -n "$1" && add_arg "-D$1"
}
add_output () {
  test -n "$1" && arg_output="$1"
}
declare arg_dep_output
declare arg_dep_target
arg_dep_output.set () {
  test -n "$1" && arg_dep_output="$1"
}
arg_dep_target.push () {
  test -n "$1" && arg_dep_target="$arg_dep_target${arg_dep_target:+ }$1"
}
function arg_dep_target.push-quoted {
  local file="$1" src dst
  src='$' dst='$$'
  file="${file//"$src"/"$dst"}"
  src=' ' dst='\ '
  file="${file//"$src"/"$dst"}"
  arg_dep_target.push "$file"
}

search_object_file () {
  local file="$1"
  case "${file##*.}" in
  o)
      local file2="${file%.o}.obj"
      if test -e "$file2"; then
        echo "$file2"
      else
        echo "$file"
      fi
      ;;
  a)
      local file2="${file%.a}.lib"
      local file3="${file2#lib}"
      if test -e "$file3"; then
        echo "$file3"
      elif test -e "$file2"; then
        echo "$file2"
      else
        echo "$file"
      fi
      ;;
  *)
      echo "$file"
      ;;
  esac
}
#------------------------------------------------------------------------------
# read arguments

fMM='' # -M, -MM, -MD, -MMD
fMP='' # -MP
fMD='' # -MD
fC=''  # -c
fG=''  # -g

arg_link_specified=

shopt -s extglob
while test $# -gt 0; do
  case "$1" in
  --help) cl -? | $ICONV ; exit   ;;
  --version) cl | $ICONV ; exit   ;;
  -I)  shift; add_incdir "$1"     ;;
  -I*)        add_incdir "${1:2}" ;;
  -L)  shift; add_libdir "$1"     ;;
  -L*)        add_libdir "${1:2}" ;;
  -D)  shift; add_define "$1"     ;;
  -D*)        add_define "${1:2}" ;;
  -o)  shift; add_output "$1"     ;;
  -o*)        add_output "${1:2}" ;;
  -l*) add_larg "${1:2}.lib"      ;;
  @(-E|-O2|-O1|-Wall))
      add_arg "$1"
      ;;
  -c)
    add_arg "$1"
    fC='c'
    ;;
  -g) add_arg "-Z7" ;;
  -shared) add_arg "-LD" ;;
  #----------------------------------------------------------------------------
  # Optimization Options
  -O0)    add_arg "-Od" ;;
  -O|-O1) add_arg "-O1" ;;
  -O2)    add_arg "-O2" ;;
  -O3)    add_arg "-Ox" ;;
  -Os)    add_arg "-Os" ;;
  -fast)
    add_arg "-Ox"
    add_arg "-GL"
    add_arg "-arch:SSE2"
    ;;
  -fomit-frame-pointer)
    add_arg "-Oy" ;;
  -fno-omit-frame-pointer)
    add_arg "-Oy-" ;;
  #----------------------------------------------------------------------------
  # Dependencies Options
  (-M)   fMM=M         ;; # fMM = mode: output dependencies
  (-MM)  fMM=MM        ;;
  (-MD)  fMM=M;  fMD=1 ;;
  (-MMD) fMM=MM; fMD=1 ;;
  (-MF)  shift; arg_dep_output.set "$1"     ;;
  (-MF*)        arg_dep_output.set "${1:3}" ;;
  (-MP)  fMP=1 ;;
  (-MT)  shift; arg_dep_target.push "$1" ;;
  (-MT*)        arg_dep_target.push "${1:3}" ;;
  (-MQ)  shift; arg_dep_target.push-quoted "$1" ;;
  (-MQ*)        arg_dep_target.push-quoted "${1:3}" ;;
  #----------------------------------------------------------------------------
  -)
    # from standard input
    push_tmpfile __cxxtmp.-.cpp
    cat /dev/stdin > __cxxtmp.-.cpp
    push_inputfile __cxxtmp.-.cpp
    ;;
  -xc++)
    # language specification (ignore)
    ;;
  -W*)
    case "$1" in
    -Wunknown-pragmas)     add_arg -w14068 ;;
    -Wno-unknown-pragmas)  add_arg -wd4068 ;;
    -Wunused)
      add_arg -w14505 -w14102 -w14100 -w14555 -w14189 ;;
    -Wno-unused)
      add_arg -wd4505 -wd4102 -wd4100 -wd4555 -wd4189 ;;
    -Wunused-function)     add_arg -w14505 ;;
    -Wno-unused-function)  add_arg -wd4505 ;;
    -Wunused-label)        add_arg -w14102 ;;
    -Wno-unused-label)     add_arg -wd4102 ;;
    -Wunused-parameter)    add_arg -w14100 ;;
    -Wno-unused-parameter) add_arg -wd4100 ;;
    -Wunused-value)        add_arg -w14555 ;;
    -Wno-unused-value)     add_arg -wd4555 ;;
    -Wunused-variable)     add_arg -w14189 ;;
    -Wno-unused-variable)  add_arg -wd4189 ;;
    -W)                    add_arg -Wall   ;; # 旧 gcc では -Wextra に等価?
    # TODO 色々の警告を追加
    -W*) echo "cxx-cl: unrecognized option '$1' (ignored)" ;;
    esac
    ;;
  -x*|-std=*)
    echo "cxx-cl: unrecognized option '$1' (ignored)"
    ;;
  -*)
    echo "cxx-cl: unrecognized option '$1'"
    exit 1
    ;;
  *.@(c|C|cpp|cxx|cc))
    push_inputfile "$1"
    ;;
  /link)
    arg_link_specified=1
    ;;
  *)
    if test -n "$arg_link_specified"; then
      add_larg "$(search_object_file "$1")"
    else
      add_arg "$(search_object_file "$1")"
    fi
    ;;
  esac
  shift
done

#------------------------------------------------------------------------------

output_dependencies2 () {
  local compile_argument=
  if [[ -z $fC ]]; then
    compile_argument="-c"
  fi

  # determine dep_output
  if test -n "$arg_dep_output"; then
    local dep_output="$arg_dep_output"
  elif test -n "$fMD"; then
    if test -n "$arg_output"; then
      local dep_output="${arg_output}.d"
    elif test -n "$first_inputfile"; then
      local dep_output="$(echo -n "$first_inputfile"|sed 's/\.\(c\|C\|cpp\|cxx\|cc\)$//').d"
    else
      local dep_output=/dev/stdout
    fi
  else
    if test -n "$arg_output"; then
      local dep_output="$arg_output"
    else
      local dep_output=/dev/stdout
    fi
  fi

  if test -n "$fMP"; then
    local dep_output_phony_targets=1
  else
    local dep_output_phony_targets=0
  fi

  if test "$1" == MM; then
    # output only local dependencies
    local PWD_W="$(cygpath -w "$PWD/"|tr A-Z a-z|sed 's/[][\\\/()\^\$]/\\&/g')"
    #echo PWD_W=$PWD_W > /dev/stderr
    local CORE='if(line ~ /'"$PWD_W"'/){
          sub(/'"$PWD_W"'/,"");
          deps=deps " \\\n" line;
        }';
  else
    # output all dependencies
    local CORE='deps=deps " \\\n" line;';
  fi

  local -a inputtmps
  for file in "${inputfiles[@]}"; do
    test -e "$file" || continue
    case "$file" in
    (__cxxtmp.*.cpp)
      inputtmps[${#inputtmps[@]}]="$file"
      push_tmpfile "${tmp%.*}.obj"
      ;;
    (*.c|*.C|*.cpp|*.cxx|*.cc)
      if test "${file%/*}" != "$file"; then
        local tmp="${file%/*}/__cxxtmp.${file##*/}"
        local tmp_obj="__cxxtmp.${file##*/}"
        tmp_obj="${tmp_obj%.*}.obj"
      else
        local tmp="__cxxtmp.$file"
        local tmp_obj="__cxxtmp.${file%.*}.obj"
      fi

      inputtmps[${#inputtmps[@]}]="$tmp"
      push_tmpfile "$tmp"
      push_tmpfile "$tmp_obj"
      cp -pf "$file" "$tmp" ;;
    (*)
      inputtmps[${#inputtmps[@]}]="$file"
      ;;
    esac
  done

  IFS=';' eval 'export mcxx_inputfiles="${inputfiles[*]}"'
  echo cl -EHsc $compile_argument -showIncludes "${clargs[@]}" "${inputtmps[@]}" >&2
  cl -EHsc $compile_argument -showIncludes "${clargs[@]}" "${inputtmps[@]}" \
    1> >($ICONV | awk '
      # @fn initialize_fullpath_dict()
      #   fullpath_dict: 入力ファイル名 → 入力ファイルパス の辞書を作成する。
      #   環境変数 mcxx_inputfiles を ; で区切って入力ファイル名とする。
      # @var[out] fullpath_dict[name] = file
      function initialize_fullpath_dict( _files,_len,_i,_file,_name){
        _len=split(ENVIRON["mcxx_inputfiles"],_files,";");
        for(_i=1;_i<=_len;_i++){
          _file=_files[_i];
          _name=_file;

          sub(/^.+\//,"",_name);
          fullpath_dict[_name]=_file;
          # print "dbg: fullpath_dict[" _name "]=" _file >"/dev/stderr";
        }
      }

      BEGIN{
        dep_target="'"$arg_dep_target"'"
        initialize_fullpath_dict();
      }

      function phony_add(file){
        if(phony_added[file])return;
        phony_added[file]=1;
        phony_targets=phony_targets file ": \n\n";
      }
      function phony_print(file){
        if('$dep_output_phony_targets'){
          print phony_targets
        }
      }

      function output_deps(){
        if(deps=="")return;
        print deps "\n";
        deps="";
        for(file in included)
          delete included[file];
      }

      /^__cxxtmp\.-\.cpp$/{
        output_deps();
        if(dep_target!="")
          deps=dep_target ": "
        else
          deps="-: ";
        next;
      }
      /^__cxxtmp\.[^ \n]+$/{
        output_deps();
        sub(/^__cxxtmp\./,"");
        print $0 > "/dev/stderr"

        input=$0;
        if(fullpath_dict[input]!=""){
          input=fullpath_dict[input];
          # print "dbg: found " $0 " -> " input >"/dev/stderr";
        }

        if(dep_target!=""){
          deps=dep_target ": " input;
        }else{
          obj=$0;
          sub(/\.(cpp|cc|cxx|C|c)?$/,".obj",obj);
          deps=obj ": " input;
        }
        next;
      }
      /^(Note|メモ): (including file|インクルード ファイル): ?/{
        if(deps=="")deps="-: "
        sub(/^(Note|メモ): (including file|インクルード ファイル): ?/,"");

        file=$0;
        sub(/^ */,"",file);
        gsub(/\\/,"/",file);
        # gsub(/ /,"\\\\ ",file);
        gsub(/ /,"\\ ",file);
        gsub(/\$/,"$$");
        if(file ~ /^[a-zA-Z]:\//)
          file="/cygdrive/" tolower(substr(file,1,1)) substr(file,3);

        # guard
        if(included[file])next;
        included[file]=1;
        phony_add(file);

        # pad=$0;
        # sub(/[^ ].*$/,"",pad);
        pad=" "

        line=pad file;

        '"$CORE"'
        next;
      }
      {
        print $0 > "/dev/stderr"
      }
      END{
        output_deps();
        phony_print();
      }
    '>"$dep_output") \
    2> >($ICONV >&2)
  ret=$?
}

#------------------------------------------------------------------------------

force_link () {
  # to calm makefile
  local src="$1"
  local dst="$2" # must be same directory
  test "$src" == "$dst" && return
  test -h "$dst" && return
  test -e "$dst" && /bin/rm "$dst"
  ln -s "${src##*/}" "$dst"
}

function simple_compile {
  # compiles
  ((${#linkargs[*]})) && fLink=/link
  echo cl -EHsc "${clargs[@]}" "${inputfiles[@]}" $fLink "${linkargs[@]}"
  if [[ $NCONV ]]; then
    cl -EHsc "${clargs[@]}" "${inputfiles[@]}" $fLink "${linkargs[@]}"
  else
    cl -EHsc "${clargs[@]}" "${inputfiles[@]}" $fLink "${linkargs[@]}" \
       1> >($ICONV   ) \
       2> >($ICONV>&2)
  fi
  ret=$?
}

function generate_outputfile_arguments {
  if [[ $fC ]]; then
    if [[ $arg_output && ${#inputfiles[@]} -eq 1 ]]; then
      if [[ ${arg_output##*.} == o ]]; then
        force_link "${arg_output%.o}.obj" "$arg_output"
        arg_output="${arg_output%.o}.obj"
      fi
      output_object=$(cygpath -w "${arg_output}")
      add_arg "-Fo$output_object"
    fi
  else
    [[ -z $arg_output ]] && arg_output=a
    arg_output_w="$(cygpath -w "${arg_output%.exe}")"
    add_arg "-Fe$arg_output_w"
    output_object="${arg_output_w%.exe}.obj"
    if [[ ${#inputfiles[@]} -eq 1 ]]; then
      add_arg "-Fo$output_object"
    fi
  fi

  # if test -n "$fG" -a -n "$output_object"; then
  #   add_arg "-Z7"
  #   # add_arg "-Fd${output_object%.obj}.pdb"
  # fi
}

fAnotherCompileForDependencies=
if [[ $fAnotherCompileForDependencies ]]; then
  if test "$fMM" == M; then
    output_dependencies2 M
  elif test "$fMM" == MM; then
    output_dependencies2 MM
  elif [[ $DEPENDENCIES_OUTPUT ]]; then
    arg_dep_output="$DEPENDENCIES_OUTPUT"
    output_dependencies2 MM
  elif [[ $SUNPRO_DEPENDENCIES_OUTPUT ]]; then
    arg_dep_output="$SUNPRO_DEPENDENCIES_OUTPUT"
    output_dependencies2 M
  fi

  simple_compile
else
  generate_outputfile_arguments

  if test "$fMM" == M; then
    output_dependencies2 M
  elif test "$fMM" == MM; then
    output_dependencies2 MM
  elif [[ $DEPENDENCIES_OUTPUT ]]; then
    arg_dep_output="$DEPENDENCIES_OUTPUT"
    output_dependencies2 MM
  elif [[ $SUNPRO_DEPENDENCIES_OUTPUT ]]; then
    arg_dep_output="$SUNPRO_DEPENDENCIES_OUTPUT"
    output_dependencies2 M
  else
    simple_compile
  fi
fi

((${#tmpfiles[*]})) && /bin/rm -f "${tmpfiles[@]}"
exit $ret
