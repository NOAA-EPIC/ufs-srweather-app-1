#!/bin/bash

# usage instructions
usage () {
cat << EOF_USAGE
Usage: $0 [OPTIONS] ...

OPTIONS
  -h, --help
      show this help guide
  -p, --platform=PLATFORM
      name of machine you are building on
      (e.g. cheyenne | hera | jet | orion | wcoss2)
  -c, --compiler=COMPILER
      compiler to use; default depends on platform
      (e.g. intel | gnu | cray | gccgfortran)
  --remove
      removes existing build directory
  --clean
      removes existing build directory and all other build artifacts
  --build-dir=BUILD_DIR
      build directory
  --bin-dir=BIN_DIR
      installation binary directory name ("exec" by default; any name is available)
  --build-jobs=BUILD_JOBS
      number of build jobs; defaults to 4
  --sub-modules
      remove sub-component modules 
  -v, --verbose
      build with verbose output

default = show all new files

EOF_USAGE
}

# print settings
settings () {
cat << EOF_SETTINGS
Settings:

  SRW_DIR=${SRW_DIR}
  BUILD_DIR=${BUILD_DIR}
  INSTALL_DIR=${INSTALL_DIR}
  BIN_DIR=${BIN_DIR}
  PLATFORM=${PLATFORM}
  COMPILER=${COMPILER}
  REMOVE=${REMOVE}
  CONTINUE=${CONTINUE}
  BUILD_JOBS=${BUILD_JOBS}
  VERBOSE=${VERBOSE}

EOF_SETTINGS
}

# print usage error and exit
usage_error () {
  printf "ERROR: $1\n" >&2
  usage >&2
  exit 1
}

# default settings
LCL_PID=$$
SRW_DIR=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )" && pwd -P)
MACHINE_SETUP=${SRW_DIR}/src/UFS_UTILS/sorc/machine-setup.sh
BUILD_DIR="${SRW_DIR}/build"
INSTALL_DIR=${SRW_DIR}
BIN_DIR="exec"
COMPILER=""
APPLICATION=""
CCPP_SUITES=""
ENABLE_OPTIONS=""
DISABLE_OPTIONS=""
BUILD_TYPE="RELEASE"
BUILD_JOBS=4
REMOVE=false
CONTINUE=false
VERBOSE=false

# Turn off all apps to build and choose default later
DEFAULT_BUILD=false 
BUILD_UFS="off"
BUILD_UFS_UTILS="off"
BUILD_UPP="off"
BUILD_GSI="off"
BUILD_RRFS_UTILS="off"

# Make options
CLEAN=false
BUILD=false
USE_SUB_MODULES=false #change default to true later

# process required arguments
if [[ ("$1" == "--help") || ("$1" == "-h") ]]; then
  usage
  exit 0
fi

# process optional arguments
while :; do
  case $1 in
    --help|-h) usage; exit 0 ;;
    --platform=?*|-p=?*) PLATFORM=${1#*=} ;;
    --platform|--platform=|-p|-p=) usage_error "$1 requires argument." ;;
    --compiler=?*|-c=?*) COMPILER=${1#*=} ;;
    --compiler|--compiler=|-c|-c=) usage_error "$1 requires argument." ;;
    --remove) REMOVE=true ;;
    --remove=?*|--remove=) usage_error "$1 argument ignored." ;;
    --clean) CLEAN=true ;;
    --build-dir=?*) BUILD_DIR=${1#*=} ;;
    --build-dir|--build-dir=) usage_error "$1 requires argument." ;;
    --bin-dir=?*) BIN_DIR=${1#*=} ;;
    --bin-dir|--bin-dir=) usage_error "$1 requires argument." ;;
    --build-jobs=?*) BUILD_JOBS=$((${1#*=})) ;;
    --build-jobs|--build-jobs=) usage_error "$1 requires argument." ;;
    --sub-modules) USE_SUB_MODULES=true ;;
    --verbose|-v) VERBOSE=true ;;
    --verbose=?*|--verbose=) usage_error "$1 argument ignored." ;;
    # targets
    default) DEFAULT_BUILD=false ;; 
    # unknown
    -?*|?*) usage_error "Unknown option $1" ;;
    *) break
  esac
  shift
done

# choose default apps to build
if [ "${DEFAULT_BUILD}" = true ]; then
  BUILD_UFS="on"
  BUILD_UFS_UTILS="on"
  BUILD_UPP="on"
fi

# Ensure uppercase / lowercase ============================================
APPLICATION="${APPLICATION^^}"
PLATFORM="${PLATFORM,,}"
COMPILER="${COMPILER,,}"

# check if PLATFORM is set
#if [ -z $PLATFORM ] ; then
#  printf "\nERROR: Please set PLATFORM.\n\n"
#  usage
#  exit 0
#fi

# set PLATFORM (MACHINE)
MACHINE="${PLATFORM}"
printf "PLATFORM(MACHINE)=${PLATFORM}\n" >&2

set -eu

# automatically determine compiler
if [ -z "${COMPILER}" ] ; then
  case ${PLATFORM} in
    jet|hera|gaea) COMPILER=intel ;;
    orion) COMPILER=intel ;;
    wcoss2) COMPILER=intel ;;
    cheyenne) COMPILER=intel ;;
    macos,singularity) COMPILER=gnu ;;
    odin,noaacloud) COMPILER=intel ;;
    *)
      COMPILER=intel
      printf "WARNING: Setting default COMPILER=intel for new platform ${PLATFORM}\n" >&2;
      ;;
  esac
fi

printf "COMPILER=${COMPILER}\n" >&2

# print settings
if [ "${VERBOSE}" = true ] ; then
  settings
fi

# set MODULE_FILE for this platform/compiler combination
MODULE_FILE="build_${PLATFORM}_${COMPILER}"
if [ ! -f "${SRW_DIR}/modulefiles/${MODULE_FILE}" ]; then
#  printf "ERROR: module file does not exist for platform/compiler\n" >&2
  printf "  MODULE_FILE=${MODULE_FILE}\n" >&2
  printf "  PLATFORM=${PLATFORM}\n" >&2
  printf "  COMPILER=${COMPILER}\n\n" >&2
  #printf "Please make sure PLATFORM and COMPILER are set correctly\n" >&2
  #usage >&2
  #exit 64
fi

printf "MODULE_FILE=${MODULE_FILE}\n" >&2

# if build directory already exists then exit
if [ "${REMOVE}" = true ]; then
  printf "Remove build directory\n"
  printf "  BUILD_DIR=${BUILD_DIR}\n\n"
  [[ -n ${BUILD_DIR} ]] && rm -rf ${BUILD_DIR}
elif [ "${CLEAN}" = true ]; then
  printf "Remove build directory\n"
  printf "... and other build artifacts\n"
  printf "  BUILD_DIR=${BUILD_DIR}\n\n"
  printf "  BIN_DIR=${BIN_DIR}\n\n"
  rm -rf share
  rm -rf include
  rm -f lib/*.a lib/cmake/*/*.cmake
  rm -f manage_externals/manic/*.pyc
  subs=$(find . -name .git -type d | sed 's|\.git$||g' | egrep -v '^.$|^./$')
  if [ ${USE_SUB_MODULES} == true ]; then
    echo "remove submodule clones: ${subs}"
    for sub in ${subs}; do ( set -x ; rm -rf $sub ); done
  fi
  [[ -n ${BIN_DIR} ]] && rm -rf ${BIN_DIR}
  [[ -n ${BUILD_DIR} ]] && echo "rm -rf ${BUILD_DIR}"
  echo "cleaned."
else
  if [ -d "${BUILD_DIR}" ]; then
  printf "build directory exists\n"
  printf "  BUILD_DIR=${BUILD_DIR}\n\n"
  fi
  if [ -d "${BIN_DIR}" ]; then
  printf "executables directory exists\n"
  printf "  BIN_DIR=${BIN_DIR}\n\n"
  fi
fi

git status

# Check for remaining new files
  #for f in $(find . -name .gitignore -type f) ; do ( mv $f $(dirname $f)/DONTignore ; )  ; done
  #git status | egrep -v "DONTignore|.gitignore"
  #for f in $(find . -name DONTignore -type f) ; do ( mv $f $(dirname $f)/.gitignore ; )  ; done

exit 0
