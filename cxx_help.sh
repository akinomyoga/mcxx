#!/bin/bash

bold=$'\e[1m=\e[m'
ul=$'\e[4m=\e[m'

ifold -s -i <<EOF
cxx ($mcxx_version_string)
Copyright (C) 2011-2015 Koichi Murase <myoga.murase@gmail.com>.

${bold/=/usage}

$ cxx ${ul/=/[compiler_arguments...]}
    compiles a target using the default compiler

$ CXXKEY=${ul/=/key} cxx ${ul/=/[compiler_arguments...]}
    compiles a target using the compiler specified by ${ul/=/key}

$ cxx +${ul/=/mcxx_command} ${ul/=/arguments...}
    executes ${ul/=/mcxx_command} with the specified arguments

list of ${bold/=/mcxx_command}

  cxx +${bold/=/help}
    Show this help.

  cxx +${bold/=/config} [${ul/=/options}...] ${ul/=/SCRIPTFILE}...
    Create cxx_conf.h from ${ul/=/SCRIPTFILE}. \
See ${ul/=/cxx +config --help} for details of the options and the content of ${ul/=/SCRIPTFILE}.

  cxx +${bold/=/prefix}
  cxx +${bold/=/prefix} get
      prints the cxxprefix of the default compiler

  cxx +${bold/=/prefix} list
      prints the list of the registered pairs of CXXKEY and CXXPREFIX.

  CXX=${ul/=//bin/c++-compiler} CC=${ul/=//bin/c-compiler} cxx +${bold/=/prefix} add
      registers a CXXKEY and CXXPREFIX pair for the specified compilers

  cxx +${bold/=/prefix} auto
      automatically detects compilers and registers

  cxx +${bold/=/prefix} remove ${ul/=/key/prefix}
  cxx +${bold/=/prefix} set-default ${ul/=/key/prefix}
  cxx +${bold/=/prefix} set-key ${ul/=/key/prefix} ${ul/=/newkey}

  cxx +${bold/=/get} ${ul/=/varname}
      retrieve the value of the ${ul/=/varname}:
    * cxxdir
    * env-source
    * input-charset
    * paths

EOF
