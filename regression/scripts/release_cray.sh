#!/bin/bash

##---------------------------------------------------------------------------##
## Assumptions:
##---------------------------------------------------------------------------##
## 1. Directory layout:
##    /usr/projects/draco/draco-NN_NN_NN/
##                  scripts/release_toss2.sh # this script
##                  logs/                    # build/test logs
##                  source/draco-NN_NN_NN    # svn checkout of release branch
##                  flavor/opt|debug         # released libraries/headers
## 2. Assumes that this script lives at the location above when
##    executed.

##---------------------------------------------------------------------------##
## Instructions
##---------------------------------------------------------------------------##
## 1. Set modulefiles to be loaded in named environment functions.
## 2. Update variables that control the build:
##    - $ddir
## 3. Run this script: scripts/release_cray.sh &> logs/relase-trinitite.log

#----------------------------------------------------------------------#
# Per release settings go here:
#----------------------------------------------------------------------#

# Draco install directory name (/usr/projects/draco/draco-NN_NN_NN)
export package=draco
ddir=draco-7_2_0
pdir=$ddir

# environment (use draco modules)
# release for each module set
target="`uname -n | sed -e s/[.].*//`"
case $target in
  t[rt]-fe* | t[rt]-login* )
    environments="intel1802env intel1802env-knl intel1704env intel1704env-knl";;
esac

# ============================================================================
# ====== Normally, you do not edit anything below this line ==================
# ============================================================================

##---------------------------------------------------------------------------##
## Generic setup
##---------------------------------------------------------------------------##

export script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" )
if ! [[ -d $script_dir ]]; then
  export script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi
export draco_script_dir=`readlink -f $script_dir | head -n 1`
echo "source ${draco_script_dir}/common.sh"
source ${draco_script_dir}/common.sh

# CMake options that will be included in the configuration step
export CONFIG_BASE="-DDraco_VERSION_PATCH=`echo $ddir | sed -e 's/.*_//'`"

# sets umask 0002
# sets $install_group, $install_permissions, $build_permissions
establish_permissions

export source_prefix="/usr/projects/$package/$pdir"
# use NFS locations until luster is fixed.
# scratchdir=`selectscratchdir`
if [[ -d /netscratch/$USER ]]; then
  scratchdir=/netscratch/$USER/scratch
else
  scratchdir=/usr/projects/ccsrad/scratch
  mkdir -p $scratchdir
fi
ppn=`lookupppn`

# =============================================================================
# Build types:
# - These must be copied into release_cray.msub because bash arrays cannot
#   be passed to the subshell (bash bug)
# =============================================================================

OPTIMIZE_ON="-DCMAKE_BUILD_TYPE=Release -DDRACO_LIBRARY_TYPE=SHARED"
OPTIMIZE_OFF="-DCMAKE_BUILD_TYPE=Debug  -DDRACO_LIBRARY_TYPE=SHARED"
OPTIMIZE_RWDI="-DCMAKE_BUILD_TYPE=RELWITHDEBINFO -DDRACO_LIBRARY_TYPE=SHARED -DDRACO_DBC_LEVEL=15"

LOGGING_ON="-DDRACO_DIAGNOSTICS=7 -DDRACO_TIMING=1"
LOGGING_OFF="-DDRACO_DIAGNOSTICS=0 -DDRACO_TIMING=0"

# Define the meanings of the various code versions:

VERSIONS=( "debug" "opt" "rwdi" )
OPTIONS=(\
    "$OPTIMIZE_OFF  $LOGGING_OFF" \
    "$OPTIMIZE_ON   $LOGGING_OFF" \
    "$OPTIMIZE_RWDI $LOGGING_OFF" \
)

##---------------------------------------------------------------------------##
## Environment review
##---------------------------------------------------------------------------##

verbose=1
if test $verbose == 1; then
  echo
  echo "Build environment summary:"
  echo "=========================="
  echo "script_dir       = $script_dir"
  echo "draco_script_dir = $script_dir"
  echo "source_prefix    = $source_prefix"
  echo "log_dir          = $source_prefix/logs"
  echo
  echo "package          = $package"
  echo "versions:"
  for (( i=0 ; i < ${#VERSIONS[@]} ; ++i )); do
    echo -e "   ${VERSIONS[$i]}, \t options = ${OPTIONS[$i]}"
  done
  echo
fi

##---------------------------------------------------------------------------##
## Execute the build, test and install
##---------------------------------------------------------------------------##

source $draco_script_dir/cray-env.sh

jobids=""
for env in $environments; do

  # Run the bash function defined above to load appropriate module
  # environment.
  echo -e "\nEstablish environment $env"
  echo "======================================="
  $env

  buildflavor=`flavor`
  # e.g.: buildflavor=trinitite-openmpi-1.6.5-intel-15.0.3

  export install_prefix="$source_prefix/$buildflavor"
  export build_prefix="$scratchdir/$USER/$pdir/$buildflavor"
  export draco_prefix="/usr/projects/draco/$ddir/$buildflavor"

  unset partition
  unset knlext
  case $TARGET in
    knl)
      partition="-p knl"
      knlext="-knl"
      ;;
  esac

  for (( i=0 ; i < ${#VERSIONS[@]} ; ++i )); do

    export version=${VERSIONS[$i]}
    export options=${OPTIONS[$i]}

    export CONFIG_EXTRA="$CONFIG_BASE"

    # export dry_run=1
    # config and build on front-end
    echo -e "\nConfigure and build $package for $buildflavor-$version."
    echo
    export steps="config build"
    logfile="$source_prefix/logs/release-$buildflavor-$version-cb${knlext}.log"
    run "$draco_script_dir/release.msub &> $logfile"

    # Run the tests on the back-end.
    export steps="test"
    logfile="$source_prefix/logs/release-$buildflavor-$version-t${knlext}.log"
    cmd="sbatch -J rel-draco-$buildflavor-$version -t 8:00:00 -N 1 $partition \
 --gres=craynetwork:0 -o $logfile $draco_script_dir/release.msub"
    echo -e "\nTest $package for $buildflavor-$version."
    echo "$cmd"
    jobid=`eval ${cmd}`
    sleep 1m
    # trim extra whitespace from number
    jobid=`echo ${jobid//[^0-9]/}`
    export jobids="$jobid $jobids"

    # export dry_run=0
  done
done

##---------------------------------------------------------------------------##
## Set permissions
##---------------------------------------------------------------------------##

publish_release

##---------------------------------------------------------------------------##
## End
##---------------------------------------------------------------------------##
