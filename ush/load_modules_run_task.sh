#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source necessary files.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; . $USHdir/preamble.sh; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( $READLINK -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Check arguments.
#
#-----------------------------------------------------------------------
#
if [ "$#" -ne 2 ]; then

    print_err_msg_exit "
Incorrect number of arguments specified:

  Number of arguments specified:  $#

Usage:

  ${scrfunc_fn}  task_name  jjob_fp

where the arguments are defined as follows:

  task_name:
  The name of the rocoto task for which this script will load modules
  and launch the J-job.

  jjob_fp
  The full path to the J-job script corresponding to task_name.  This
  script will launch this J-job using the \"exec\" command (which will
  first terminate this script and then launch the j-job; see man page of
  the \"exec\" command).
"

fi
#
#-----------------------------------------------------------------------
#
# Get the task name and the name of the J-job script.
#
#-----------------------------------------------------------------------
#
task_name="$1"
jjob_fp="$2"
#
#-----------------------------------------------------------------------
#
# For NCO mode we need to define job and jobid
#
#-----------------------------------------------------------------------
#
set +u
if [ ! -z ${SLURM_JOB_ID} ]; then
    export job=${SLURM_JOB_NAME}
    export jobid=${job}.${SLURM_JOB_ID}
elif [ ! -z ${PBS_JOBID} ]; then
    export job=${PBS_JOBNAME}
    export jobid=${job}.${PBS_JOBID}
else
    export job=${task_name}
    export jobid=${job}.$$
fi
set -u
#
#-----------------------------------------------------------------------
#
# Loading ufs-srweather-app build module files
#
#-----------------------------------------------------------------------
#
machine=$(echo_lowercase $MACHINE)

# source version file (build) only if it is specified in versions directory
VERSION_FILE="${HOMEdir}/versions/${BUILD_VER_FN}"
if [ -f ${VERSION_FILE} ]; then
  . ${VERSION_FILE}
fi

source "${HOMEdir}/etc/lmod-setup.sh" ${machine}
module use "${HOMEdir}/modulefiles"
module load "${BUILD_MOD_FN}" || print_err_msg_exit "\
Loading of platform- and compiler-specific module file (BUILD_MOD_FN) 
for the workflow task specified by task_name failed:
  task_name = \"${task_name}\"
  BUILD_MOD_FN = \"${BUILD_MOD_FN}\""
#
#-----------------------------------------------------------------------
#
# Set the directory (modules_dir) in which the module files for the va-
# rious workflow tasks are located.  Also, set the name of the module
# file for the specified task.
#
# A module file is a file whose first line is the "magic cookie" string
# '#%Module'.  It is interpreted by the "module load ..." command.  It
# sets environment variables (including prepending/appending to paths)
# and loads modules.
#
# The UFS SRW App repository contains module files for the
# workflow tasks in the template rocoto XML file for the FV3-LAM work-
# flow that need modules not loaded in the BUILD_MOD_FN above.
#
# The full path to a module file for a given task is
#
#   $HOMEdir/modulefiles/$machine/${task_name}.local
#
# where HOMEdir is the base directory of the workflow, machine is the
# name of the machine that we're running on (in lowercase), and task_-
# name is the name of the current task (an input to this script).
#
#-----------------------------------------------------------------------
#
modules_dir="$HOMEdir/modulefiles/tasks/$machine"
modulefile_name="${task_name}"
default_modules_dir="$HOMEdir/modulefiles"
#
#-----------------------------------------------------------------------
#
# Load the module file for the specified task on the current machine.
#
#-----------------------------------------------------------------------
#

print_info_msg "$VERBOSE" "
Loading modules for task \"${task_name}\" ..."

module use "${modules_dir}" || print_err_msg_exit "\
Call to \"module use\" command failed."

# source version file (run) only if it is specified in versions directory
VERSION_FILE="${HOMEdir}/versions/${RUN_VER_FN}"
if [ -f ${VERSION_FILE} ]; then
  . ${VERSION_FILE}
fi
#
# Load the .local module file if available for the given task
#
modulefile_local="${task_name}.local"
if [ -f ${modules_dir}/${modulefile_local} ]; then
  module load "${modulefile_local}" || print_err_msg_exit "\
  Loading .local module file (in directory specified by mod-
  ules_dir) for the specified task (task_name) failed:
    task_name = \"${task_name}\"
    modulefile_local = \"${modulefile_local}\"
    modules_dir = \"${modules_dir}\""    
fi

module list


# Modules that use conda and need an environment activated will set the
# SRW_ENV variable to the name of the environment to be activated. That
# must be done within the script, and not inside the module. Do that
# now.

if [ -n "${SRW_ENV:-}" ] ; then
  set +u
  conda activate ${SRW_ENV}
  if [ $machine = "gaea" ]; then
     conda deactivate
     conda activate ${SRW_ENV}
  fi
  set -u
fi

#
#-----------------------------------------------------------------------
#
# Use the exec command to terminate the current script and launch the
# J-job for the specified task.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Launching J-job (jjob_fp) for task \"${task_name}\" ...
  jjob_fp = \"${jjob_fp}\"
"
exec "${jjob_fp}"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1


