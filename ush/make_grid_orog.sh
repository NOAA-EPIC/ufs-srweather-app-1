#!/bin/sh -l

#
#-----------------------------------------------------------------------
#
# This script generates grid and orography files in NetCDF format that
# are required as inputs for running the FV3SAR model (i.e. the FV3 mo-
# del on a regional domain).  It in turn calls three other scripts whose
# file names are specified in the variables grid_gen_scr, orog_gen_scr,
# and orog_fltr_scr and then calls the executable defined in the varia-
# ble shave_exec.  These scripts/executable perform the following tasks:
#
# 1) grid_gen_scr:
#
#    This script generates grid files that will be used by subsequent
#    preprocessing steps.  It places its output in the temporary direc-
#    tory defined in WORKDIR_GRID (which is somewhere under TMPDIR).
#    Note that:
#
#    a) This script creates grid files for each of the 7 tiles of the
#       cubed sphere grid (where tiles 1 through 6 cover the globe, and
#       tile 7 is the regional grid located somewhere within tile 6)
#       even though the forecast will be performed only on tile 7.
#
#    b) The tile 7 grid file that this script creates includes a halo,
#       i.e. a layer of cells beyond the boundary of tile 7).  The width
#       of this halo (i.e. the number of cells in the halo in the direc-
#       tion perpendicular to the boundary of the tile) must be made
#       large enough such that the "shave" steps later below (which take
#       this file as input and generate grid files with thinner halos)
#       have a wide enough starting halo to work with.  More specifical-
#       ly, the FV3SAR model needs as inputs two grid files: one with a
#       halo that is 3 cells and another with a halo that is 4 cells 
#       wide.  Thus, the halo in the grid file that the grid_gen_scr 
#       script generates must be greater than 4 since otherwise, the
#       shave steps would shave off cells from within the interior of
#       tile 7.  We will let nhw_T7 denote the width of the halo in the
#       grid file generated by grid_gen_scr.  The "n" in this variable
#       name denotes number of cells, the "h" is used to indicate that
#       it refers to a halo region, the "w" is used to indicate that it
#       refers to a wide halo (i.e. wider than the 3-cell and 4-cell ha-
#       los that the FV3SAR model requires as inputs, and the "T7" is
#       used to indicate that the cell count is on tile 7.
#
# 2) orog_gen_scr:
#
#    This script generates the orography file.  It places its output in
#    the temporary directory defined in WORKDIR_OROG (which is somewhere
#    under TMPDIR).  Note that:
#
#    a) This script generates an orography file only on tile 7.
#
#    b) This orography file contains a halo of the same width (nhw_T7)
#       as the grid file for tile 7 generated by the grid_gen_scr script
#       in the previous step.
#
# 3) orog_fltr_scr:
#
#    This script generates a filtered version of the orography file ge-
#    nerated by the script orog_gen_scr.  This script places its output
#    in the temporary directory defined in WORKDIR_FLTR (which is some-
#    where under TMPDIR).  Note that:
#
#    a) The filtered orography file generated by this script contains a
#       halo of the same width (nhw_T7) as the (unfiltered) orography
#       file generated by script orog_gen_scr (and the grid file genera-
#       ted by grid_gen_scr).
#
#    b) In analogy with the input grid files, the FV3SAR model needs as
#       input two (filtered) orography files -- one with no halo cells
#       and another with 3.  These are obtained later below by "shaving"
#       off layers of halo cells from the (filtered) orography file ge-
#       nerated in this step.
#
# 4) shave_exec:
#
#    This "shave" executable is called 4 times to generate 4 files from
#    the tile 7 grid file generated by grid_gen_scr and the tile 7 fil-
#    tered orography file generated by orog_fltr_scr (both of which have
#    a halo of width nhw_T7 cells).  The 4 output files are placed in
#    the temporary directory defined in WORKDIR_SHVE (which is somewhere
#    under TMPDIR).  More specifically:
#
#    a) shave_exec is called to shave the halo in the tile 7 grid file
#       generated by grid_gen_scr down to a width of 3 cells and store
#       the result in a new grid file in WORKDIR_SHVE.
#
#    b) shave_exec is called to shave the halo in the tile 7 grid file
#       generated by grid_gen_scr down to a width of 4 cells and store
#       the result in a new grid file in WORKDIR_SHVE.
#
#    c) shave_exec is called to shave the halo in the tile 7 filtered
#       orography file generated by orog_fltr_scr down to a width of 0
#       cells (i.e. no halo) and store the result in a new filtered oro-
#       graphy file in WORKDIR_SHVE.
#
#    d) shave_exec is called to shave the halo in the tile 7 filtered
#       orography file generated by orog_fltr_scr down to a width of 4
#       cells and store the result in a new filtered orography file in
#       WORKDIR_SHVE.
#
#-----------------------------------------------------------------------
#

#
#-----------------------------------------------------------------------
#
# Source the variable definitions script.                                                                                                         
#
#-----------------------------------------------------------------------
#
. $SCRIPT_VAR_DEFNS_FP
#
#-----------------------------------------------------------------------
#
# Source function definition files.
#
#-----------------------------------------------------------------------
#
. $USHDIR/source_funcs.sh
#
#-----------------------------------------------------------------------
#
# Source file containing definitions of mathematical and physical con-
# stants.
#
#-----------------------------------------------------------------------
#
. ${USHDIR}/constants.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u -x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Export select variables.
#
#-----------------------------------------------------------------------
#
export gtype
export stretch_fac
#
#-----------------------------------------------------------------------
#
# Set the file names of the scripts to use for generating the grid
# files, the orography files, and for filtering the orography files,
# respectively.  Also, set the name of the executable file used to
# "shave" (i.e. remove the halo from) certain grid and orography
# files.  The shaving is needed only for the gtype="regional" case.
#
#-----------------------------------------------------------------------
#
grid_gen_scr="fv3gfs_make_grid.sh"
orog_gen_scr="fv3gfs_make_orog.sh"
orog_fltr_scr="fv3gfs_filter_topo.sh"
shave_exec="shave.x"
#
#-----------------------------------------------------------------------
#
# The orography code runs with threads.  On Cray, the code is optimized
# for six threads.  Do not change.
# Note that OMP_NUM_THREADS and OMP_STACKSIZE only affect the threaded   <== I don't think this is true.  Remove??
# executions on Cray; they don't affect executions on theia.
#
#-----------------------------------------------------------------------
#
export OMP_NUM_THREADS=6
export OMP_STACKSIZE=2048m
#
#-----------------------------------------------------------------------
#
# Load modules and set various computational parameters and directories.
#
# topo_dir specifies the directory in which input files needed for gene-
# rating the orography (topography) files are located.
#
#-----------------------------------------------------------------------
#
case $MACHINE in


"WCOSS_C" | "WCOSS")
#
  { save_shell_opts; set +x; } > /dev/null 2>&1

  . $MODULESHOME/init/sh
  module load PrgEnv-intel cfp-intel-sandybridge/1.1.0
  module list

  { restore_shell_opts; } > /dev/null 2>&1

  export NODES=1
  export APRUN="aprun -n 1 -N 1 -j 1 -d 1 -cc depth"
  export KMP_AFFINITY=disabled
  export topo_dir="/gpfs/hps/emc/global/noscrub/emc.glopara/svn/fv3gfs/fix/fix_orog"

  ulimit -s unlimited
  ulimit -a
  ;;


"THEIA")
#
  { save_shell_opts; set +x; } > /dev/null 2>&1

  . /apps/lmod/lmod/init/sh
  module purge
  module load intel/16.1.150
  module load impi
  module load hdf5/1.8.14
  module load netcdf/4.3.0
  module list

  { restore_shell_opts; } > /dev/null 2>&1

  export APRUN="time"
  export topo_dir="/scratch4/NCEPDEV/global/save/glopara/svn/fv3gfs/fix/fix_orog"

  ulimit -s unlimited
  ulimit -a
  ;;


"JET")
#
  { save_shell_opts; set +x; } > /dev/null 2>&1

  . /apps/lmod/lmod/init/sh
  module purge
  module load newdefaults
  module load intel/15.0.3.187
  module load impi/5.1.1.109
  module load szip
  module load hdf5
  module load netcdf4/4.2.1.1
  module list

  { restore_shell_opts; } > /dev/null 2>&1

  export APRUN="time"
  export topo_dir="/lfs3/projects/hpc-wof1/ywang/regional_fv3/fix/fix_orog"
#  . $USHDIR/set_stack_limit_jet.sh
  ulimit -a
  ;;


"ODIN")
#
  export APRUN="srun -n 1"
  export topo_dir="/scratch/ywang/fix/theia_fix/fix_orog"

  ulimit -s unlimited
  ulimit -a
  ;;


esac
#
#-----------------------------------------------------------------------
#
# Set and export the variable exec_dir.  This is needed by some of the 
# scripts called by this script.
#
#-----------------------------------------------------------------------
#
export exec_dir="$EXECDIR"
#
#-----------------------------------------------------------------------
#
# Create the (cycle-independent) subdirectories under the work directory
# (WORKDIR) that are needed by the various steps and substeps in this
# script.  Note that the workflow generation script creates the work di-
# rectory (WORKDIR), so we do not need to create it here.
#
#-----------------------------------------------------------------------
#
check_for_preexist_dir $WORKDIR_GRID $preexisting_dir_method
mkdir_vrfy -p "$WORKDIR_GRID"

check_for_preexist_dir $WORKDIR_OROG $preexisting_dir_method
mkdir_vrfy -p "$WORKDIR_OROG"

check_for_preexist_dir $WORKDIR_FLTR $preexisting_dir_method
mkdir_vrfy -p "$WORKDIR_FLTR"

check_for_preexist_dir $WORKDIR_SHVE $preexisting_dir_method
mkdir_vrfy -p "$WORKDIR_SHVE"
#
#-----------------------------------------------------------------------
#
# Generate grid files.
#
# The following will create 7 grid files (one per tile, where the 7th
# "tile" is the grid that covers the regional domain) named
#
#   ${CRES}_grid.tileN.nc for N=1,...,7.
#
# It will also create a mosaic file named ${CRES}_mosaic.nc that con-
# tains information only about tile 7 (i.e. it does not have any infor-
# mation on how tiles 1 through 6 are connected or that tile 7 is within
# tile 6).  All these files will be placed in the directory specified by
# WORKDIR_GRID.  Note that the file for tile 7 will include a halo of
# width nhw_T7 cells.
#
# Since tiles 1 through 6 are not needed to run the FV3SAR model and are
# not used later on in any other preprocessing steps, it is not clear
# why they are generated.  It might be because it is not possible to di-
# rectly generate a standalone regional grid using the make_hgrid uti-
# lity/executable that grid_gen_scr calls, i.e. it might be because with
# make_hgrid, one has to either create just the 6 global tiles or create
# the 6 global tiles plus the regional (tile 7), and then for the case
# of a regional simulation (i.e. gtype="regional", which is always the
# case here) just not use the 6 global tiles.
#
# The grid_gen_scr script called below takes its next-to-last argument
# and passes it as an argument to the --halo flag of the make_hgrid uti-
# lity/executable.  make_hgrid then checks that a regional (or nested)
# grid of size specified by the arguments to its --istart_nest, --iend_-
# nest, --jstart_nest, and --jend_nest flags with a halo around it of
# size specified by the argument to the --halo flag does not extend be-
# yond the boundaries of the parent grid (tile 6).  In this case, since
# the values passed to the --istart_nest, ..., and --jend_nest flags al-
# ready include a halo (because these arguments are $istart_rgnl_with_-
# halo_T6SG, $iend_rgnl_wide_halo_T6SG, $jstart_rgnl_wide_halo_T6SG, and
# $jend_rgnl_wide_halo_T6SG), it is reasonable to pass as the argument
# to --halo a zero.  However, make_hgrid requires that the argument to
# --halo be at least 1, so below, we pass a 1 as the next-to-last argu-
# ment to grid_gen_scr.
#
# More information on make_hgrid:
# ------------------------------
#
# The grid_gen_scr called below in turn calls the make_hgrid executable
# as follows:
#
#   make_hgrid \
#   --grid_type gnomonic_ed \
#   --nlon 2*${RES} \
#   --grid_name C${RES}_grid \
#   --do_schmidt --stretch_factor ${stretch_fac} \
#   --target_lon ${lon_ctr_T6} --target_lat ${lat_ctr_T6} \
#   --nest_grid --parent_tile 6 --refine_ratio ${refine_ratio} \
#   --istart_nest ${istart_rgnl_wide_halo_T6SG} \
#   --jstart_nest ${jstart_rgnl_wide_halo_T6SG} \
#   --iend_nest ${iend_rgnl_wide_halo_T6SG} \
#   --jend_nest ${jend_rgnl_wide_halo_T6SG} \
#   --halo ${nh3_T7} \
#   --great_circle_algorithm
#
# This creates the 7 grid files ${CRES}_grid.tileN.nc for N=1,...,7.
# The 7th file ${CRES}_grid.tile7.nc represents the regional grid, and
# the extents of the arrays in that file do not seem to include a halo,
# i.e. they are based only on the values passed via the four flags
#
#   --istart_nest ${istart_rgnl_wide_halo_T6SG}
#   --jstart_nest ${jstart_rgnl_wide_halo_T6SG}
#   --iend_nest ${iend_rgnl_wide_halo_T6SG}
#   --jend_nest ${jend_rgnl_wide_halo_T6SG}
#
# According to Rusty Benson of GFDL, the flag
#
#   --halo ${nh3_T7}
#
# only checks to make sure that the nested or regional grid combined
# with the specified halo lies completely within the parent tile.  If
# so, make_hgrid issues a warning and exits.  Thus, the --halo flag is
# not meant to be used to add a halo region to the nested or regional
# grid whose limits are specified by the flags --istart_nest, --iend_-
# nest, --jstart_nest, and --jend_nest.
#
# Note also that make_hgrid has an --out_halo option that, according to
# the documentation, is meant to output extra halo cells around the
# nested or regional grid boundary in the file generated by make_hgrid.
# However, according to Rusty Benson of GFDL, this flag was originally
# created for a special purpose and is limited to only outputting at
# most 1 extra halo point.  Thus, it should not be used.
#
#-----------------------------------------------------------------------
#
print_info_msg_verbose "Starting grid file generation..."

if [ "$grid_gen_method" = "GFDLgrid" ]; then

  $USHDIR/$grid_gen_scr \
    $RES \
    $WORKDIR_GRID \
    $stretch_fac $lon_ctr_T6 $lat_ctr_T6 $refine_ratio \
    $istart_rgnl_wide_halo_T6SG $jstart_rgnl_wide_halo_T6SG \
    $iend_rgnl_wide_halo_T6SG $jend_rgnl_wide_halo_T6SG \
    1 $USHDIR || print_err_msg_exit "\
Call to script that generates grid files returned with nonzero exit code."

  tile_rgnl=7
  grid_fn="${CRES}_grid.tile${tile_rgnl}.nc"
  $EXECDIR/global_equiv_resol "$WORKDIR_GRID/$grid_fn" || print_err_msg_exit "\ 
Call to executable that calculates equivalent global uniform cubed sphere
resolution returned with nonzero exit code."

  cd_vrfy $WORKDIR_GRID

  RES_equiv=$( ncdump -h "$grid_fn" | grep -o ":RES_equiv = [0-9]\+" | grep -o "[0-9]")
  RES_equiv=${RES_equiv//$'\n'/}
printf "%s\n" "RES_equiv = $RES_equiv"
  CRES_equiv="C${RES_equiv}"
printf "%s\n" "CRES_equiv = $CRES_equiv"

elif [ "$grid_gen_method" = "JPgrid" ]; then
#
#-----------------------------------------------------------------------
#
# Set the full path to the namelist file for the executable that gene-
# rates a regional grid using Jim Purser's method.  Then set parameters
# in that file.
#
#-----------------------------------------------------------------------
#
  RGNL_GRID_NML_FP="$WORKDIR_GRID/$RGNL_GRID_NML_FN"
  cp_vrfy $TEMPLATE_DIR/$RGNL_GRID_NML_FN $RGNL_GRID_NML_FP 

  print_info_msg_verbose "\
Setting parameters in file:
  RGNL_GRID_NML_FP = \"$RGNL_GRID_NML_FP\""
#
# Set parameters.
#
  set_file_param "$RGNL_GRID_NML_FP" "plon" "$lon_rgnl_ctr"
  set_file_param "$RGNL_GRID_NML_FP" "plat" "$lat_rgnl_ctr"
  set_file_param "$RGNL_GRID_NML_FP" "delx" "$del_angle_x_SG"
  set_file_param "$RGNL_GRID_NML_FP" "dely" "$del_angle_y_SG"
  set_file_param "$RGNL_GRID_NML_FP" "lx" "$mns_nx_T7_pls_wide_halo"
  set_file_param "$RGNL_GRID_NML_FP" "ly" "$mns_ny_T7_pls_wide_halo"
  set_file_param "$RGNL_GRID_NML_FP" "a" "$a_grid_param"
  set_file_param "$RGNL_GRID_NML_FP" "k" "$k_grid_param"

  cd_vrfy $WORKDIR_GRID

  $EXECDIR/regional_grid $RGNL_GRID_NML_FP || print_err_msg_exit "\ 
Call to executable that generates grid file (Jim Purser version) returned 
with nonzero exit code."

  tile_rgnl=7
  grid_fn="regional_grid.nc"
  $EXECDIR/global_equiv_resol "$WORKDIR_GRID/$grid_fn" || print_err_msg_exit "\ 
Call to executable that calculates equivalent global uniform cubed sphere
resolution returned with nonzero exit code."

  RES_equiv=$( ncdump -h "$grid_fn" | grep -o ":RES_equiv = [0-9]\+" | grep -o "[0-9]")
  RES_equiv=${RES_equiv//$'\n'/}
printf "%s\n" "RES_equiv = $RES_equiv"
  CRES_equiv="C${RES_equiv}"
printf "%s\n" "CRES_equiv = $CRES_equiv"

  grid_fn_orig="$grid_fn"
  grid_fn="${CRES_equiv}_grid.tile${tile_rgnl}.nc"
  mv_vrfy $grid_fn_orig $grid_fn

  $EXECDIR/mosaic_file $CRES_equiv || print_err_msg_exit "\ 
Call to executable that creates a grid mosaic file returned with nonzero
exit code."
#
# RES and CRES need to be set here in order for the rest of the script
# (that was originally written for a grid with grid_gen_method set to 
# "GFDLgrid") to work for a grid with grid_gen_method set to "JPgrid".
#
  RES="$RES_equiv"
  CRES="$CRES_equiv"

  set_file_param "${SCRIPT_VAR_DEFNS_FP}" "RES" "$RES"
  set_file_param "${SCRIPT_VAR_DEFNS_FP}" "CRES" "$CRES"

fi
#
#-----------------------------------------------------------------------
#
# Set the globally equivalent values of RES and CRES in the variable de-
# finitions file.
#
#-----------------------------------------------------------------------
#
#set_file_param "${SCRIPT_VAR_DEFNS_FP}" "RES_equiv" "${RES_equiv}"
#set_file_param "${SCRIPT_VAR_DEFNS_FP}" "CRES_equiv" "${CRES_equiv}"
#
#-----------------------------------------------------------------------
#
# Define the tile number for the regional grid.
#
#-----------------------------------------------------------------------
#
tile=7
#
#-----------------------------------------------------------------------
#
# For clarity, rename the tile 7 grid file such that its new name con-
# tains the halo size.  Then create a link whose name doesn't contain
# the halo size that points to this file.
#
#-----------------------------------------------------------------------
#
cd_vrfy $WORKDIR_GRID
mv_vrfy ${CRES}_grid.tile${tile}.nc \
        ${CRES}_grid.tile${tile}.halo${nhw_T7}.nc
ln_vrfy -sf ${CRES}_grid.tile${tile}.halo${nhw_T7}.nc \
            ${CRES}_grid.tile${tile}.nc
cd_vrfy -

print_info_msg_verbose "Grid file generation complete."
#
#-----------------------------------------------------------------------
#
# Generate an orography file corresponding to tile 7 (the regional do-
# main) only.
#
# The following will create an orography file named
#
#   oro.${CRES}.tile7.nc
#
# and will place it in WORKDIR_OROG.  Note that this file will include
# orography for a halo of width nhw_T7 cells around tile 7.  The follow-
# ing will also create a work directory called tile7 under WORKDIR_OROG.
# This work directory can be removed after the orography file has been
# created (it is currently not deleted).
#
#-----------------------------------------------------------------------
#
print_info_msg_verbose "Starting orography file generation..."

#
# We need to export WORKDIR_OROG so that orog_gen_scr sets its internal
# work directory correctly for the regional case.
#
export WORKDIR_OROG

case $MACHINE in


"WCOSS_C" | "WCOSS")
#
# On WCOSS and WCOSS_C, use cfp to run multiple tiles simulatneously for
# the orography.  For now, we have only one tile in the regional case,
# but in the future we will have more.  First, create an input file for
# cfp.
#
  printf "%s\n" "\
$USHDIR/$orog_gen_scr \
$RES \
$tile \
$WORKDIR_GRID \
$WORKDIR_OROG \
$USHDIR \
$topo_dir \
$TMPDIR" \
  >> $TMPDIR/orog.file1

  aprun -j 1 -n 4 -N 4 -d 6 -cc depth cfp $TMPDIR/orog.file1
  rm_vrfy $TMPDIR/orog.file1
  ;;


"THEIA" | "JET" | "ODIN")
# NOTE:  We undefined TMPDIR, but things still seem to work.  WHY???
  $USHDIR/$orog_gen_scr \
    $RES $tile $WORKDIR_GRID $WORKDIR_OROG $USHDIR $topo_dir $TMPDIR || \
  print_err_msg_exit "\
Call to script that generates unfiltered orography file returned with 
nonzero exit code."
  ;;


esac
#
#-----------------------------------------------------------------------
#
# For clarity, rename the tile 7 orography file such that its new name
# contains the halo size.  Then create a link whose name doesn't contain
# the halo size that points to this file.
#
#-----------------------------------------------------------------------
#
cd_vrfy $WORKDIR_OROG
mv_vrfy oro.${CRES}.tile${tile}.nc \
        oro.${CRES}.tile${tile}.halo${nhw_T7}.nc
ln_vrfy -sf oro.${CRES}.tile${tile}.halo${nhw_T7}.nc \
            oro.${CRES}.tile${tile}.nc
cd_vrfy -

print_info_msg_verbose "Orography file generation complete."
#
#-----------------------------------------------------------------------
#
# Set paramters used in filtering of the orography.
#
#-----------------------------------------------------------------------
#
print_info_msg_verbose "Setting orography filtering parameters..."

# Need to fix the following (also above).  Then redo to get cell_size_avg.
#cd_vrfy $WORKDIR_GRID
#$SORCDIR/regional_grid/regional_grid $RGNL_GRID_NML_FP $CRES || print_err_msg_exit "\ 
#Call to script that generates grid file (Jim Purser version) returned with nonzero exit code."
#${CRES}_grid.tile${tile}.halo${nhw_T7}.nc


#if [ "$grid_gen_method" = "GFDLgrid" ]; then
#  RES_eff=$( bc -l <<< "$RES*$refine_ratio" )
#elif [ "$grid_gen_method" = "JPgrid" ]; then
#  grid_size_eff=$( "($delx + $dely)/2" )
#echo "grid_size_eff = $grid_size_eff"
#  RES_eff=$( bc -l <<< "2*$pi_geom*$radius_Earth/(4*$grid_size_eff)" )
#fi
#RES_eff=$( printf "%.0f\n" $RES_eff )
#echo
#echo "RES_eff = $RES_eff"

# Can also call it the "equivalent" global unstretched resolution.

RES_array=(         "48"    "96"    "192"   "384"   "768"   "1152"  "3072")
cd4_array=(         "0.12"  "0.12"  "0.15"  "0.15"  "0.15"  "0.15"  "0.15")
max_slope_array=(   "0.12"  "0.12"  "0.12"  "0.12"  "0.12"  "0.16"  "0.30")
n_del2_weak_array=( "4"     "8"     "12"    "12"    "16"    "20"    "24")
peak_fac_array=(    "1.1"   "1.1"   "1.05"  "1.0"   "1.0"   "1.0"   "1.0")

#
cd4=$( interpol_to_arbit_CRES $RES_equiv RES_array cd4_array )
echo "====>>>> cd4 = $cd4"
#
max_slope=$( interpol_to_arbit_CRES $RES_equiv RES_array max_slope_array )
echo "====>>>> max_slope = $max_slope"
#
n_del2_weak=$( interpol_to_arbit_CRES $RES_equiv RES_array n_del2_weak_array )
# n_del2_weak is defined to be of integer type in the filter_topo code 
# that uses it, so round it to the nearest integer.  Otherwise, the code
# might break on some machines/compilers.
n_del2_weak=$( printf "%.0f" ${n_del2_weak} )   # cast to integer, Y. Wang
echo "====>>>> n_del2_weak = $n_del2_weak"
#
peak_fac=$( interpol_to_arbit_CRES $RES_equiv RES_array peak_fac_array )
echo "====>>>> peak_fac = $peak_fac"
#


if [ 0 = 1 ]; then

if [ $RES -eq 48 ]; then
  export cd4=0.12; export max_slope=0.12; export n_del2_weak=4;  export peak_fac=1.1
elif [ $RES -eq 96 ]; then
  export cd4=0.12; export max_slope=0.12; export n_del2_weak=8;  export peak_fac=1.1
elif [ $RES -eq 192 ]; then
  export cd4=0.15; export max_slope=0.12; export n_del2_weak=12; export peak_fac=1.05
elif [ $RES -eq 384 ]; then
  export cd4=0.15; export max_slope=0.12; export n_del2_weak=12; export peak_fac=1.0
elif [ $RES -eq 768 ]; then
  export cd4=0.15; export max_slope=0.12; export n_del2_weak=16; export peak_fac=1.0
elif [ $RES -eq 1152 ]; then
  export cd4=0.15; export max_slope=0.16; export n_del2_weak=20; export peak_fac=1.0
elif [ $RES -eq 3072 ]; then
  export cd4=0.15; export max_slope=0.30; export n_del2_weak=24; export peak_fac=1.0
else
# This needs to be fixed - i.e. what to do about regional grids that are
# not based on a parent global cubed-sphere grid.
  export cd4=0.15; export max_slope=0.30; export n_del2_weak=24; export peak_fac=1.0
fi

fi

#
#-----------------------------------------------------------------------
#
# Generate a filtered orography file corresponding to tile 7 (the re-
# gional domain) only.
#
# The following will create a filtered orography file named
#
#   oro.${CRES}.tile7.nc
#
# and will place it in WORKDIR_FLTR.  Note that this file will include
# the filtered orography for a halo of width nhw_T7 cells around tile 7.
#
# The orography filtering script orog_fltr_scr copies the tile 7 grid
# file and the mosaic file that was created above in WORKDIR_GRID and
# the (unfiltered) tile 7 orography file created above in WORKDIR_OROG
# to WORKDIR_FLTR.  It also copies the executable that performs the fil-
# tering from EXECDIR to WORKDIR_FLTR and creates a namelist file that
# the executable needs as input.  When run, for each tile listed in the
# mosaic file, the executable replaces the unfiltered orography file
# with its filtered counterpart (i.e. it gives the filtered file the
# same name as the original unfiltered file).  Since in this (i.e.
# gtype="regional") case the mosaic file lists only tile 7, a filtered
# orography file is generated only for tile 7.  Thus, the grid files for
# the first 6 tiles that were created above in WORKDIR_GRID are not used
# and thus do not need to be copied from WORKDIR_GRID to WORKDIR_FLTR
# (to get this behavior required a small change to the orog_fltr_scr
# script that GSK has made).
#
#-----------------------------------------------------------------------
#
print_info_msg_verbose "Starting filtering of orography..."

# The script below creates absolute symlinks in $WORKDIR_FLTR.  That's 
# probably necessary for NCO but probably better to create relative 
# links for the community workflow.
$USHDIR/$orog_fltr_scr \
  $RES \
  $WORKDIR_GRID $WORKDIR_OROG $WORKDIR_FLTR \
  $cd4 $peak_fac $max_slope $n_del2_weak \
  $USHDIR $gtype || print_err_msg_exit "\
Call to script that generates filtered orography file returned with non-
zero exit code."
#
#-----------------------------------------------------------------------
#
# For clarity, rename the tile 7 filtered orography file in WORKDIR_FLTR
# such that its new name contains the halo size.  Then create a link
# whose name doesn't contain the halo size that points to the file.
#
#-----------------------------------------------------------------------
#
cd_vrfy $WORKDIR_FLTR
mv_vrfy oro.${CRES}.tile${tile}.nc \
        oro.${CRES}.tile${tile}.halo${nhw_T7}.nc
ln_vrfy -sf oro.${CRES}.tile${tile}.halo${nhw_T7}.nc \
            oro.${CRES}.tile${tile}.nc
cd_vrfy -

print_info_msg_verbose "Filtering of orography complete."
#
#-----------------------------------------------------------------------
#
# Partially "shave" the halos from the grid and orography files to gene-
# rate new grid and orography files with thinner halos that are needed
# as inputs by the FV3SAR model.  More specifically, the 4 files that
# the FV3SAR model will try to read are:
#
# 1) A regional (i.e. tile 7) grid file with a halo of 3 cells.
# 2) A regional (i.e. tile 7) grid file with a halo of 4 cells.
# 3) A regional (i.e. tile 7) filtered topography file without a halo
#    (i.e. a halo of 0 cells).
# 4) A regional (i.e. tile 7) filtered topography file with a halo of 4
#    cells.
#
# These are created below and placed in WORKDIR_FLTR.  Note that the
# grid and orography files with a halo of 4 cells are also needed as in-
# puts by the chgres program to generate boundary condition (BC) files
# with 4 rows and columns.
#
#-----------------------------------------------------------------------
#
print_info_msg_verbose "\
\"Shaving\" regional grid and filtered orography files to reduce them to
required compute size..."

cd_vrfy $WORKDIR_SHVE
#
# Create an input file for the shave executable to generate a grid file
# with a halo of 3 cells.
#
printf "%s %s %s %s %s\n" \
  $nx_T7 \
  $ny_T7 \
  $nh3_T7 \
  \'$WORKDIR_FLTR/${CRES}_grid.tile${tile}.nc\' \
  \'$WORKDIR_SHVE/${CRES}_grid.tile${tile}.halo${nh3_T7}.nc\' \
  > input.shave.grid.halo${nh3_T7}
#
# Create an input file for the shave executable to generate a grid file
# with a halo of 4 cells.
#
printf "%s %s %s %s %s\n" \
  $nx_T7 \
  $ny_T7 \
  $nh4_T7 \
  \'$WORKDIR_FLTR/${CRES}_grid.tile${tile}.nc\' \
  \'$WORKDIR_SHVE/${CRES}_grid.tile${tile}.halo${nh4_T7}.nc\' \
  > input.shave.grid.halo${nh4_T7}
#
# Create an input file for the shave executable to generate an orography
# file without a halo.
#
printf "%s %s %s %s %s\n" \
  $nx_T7 \
  $ny_T7 \
  $nh0_T7 \
  \'$WORKDIR_FLTR/oro.${CRES}.tile${tile}.nc\' \
  \'$WORKDIR_SHVE/${CRES}_oro_data.tile${tile}.halo${nh0_T7}.nc\' \
  > input.shave.orog.halo${nh0_T7}
#
# Create an input file for the shave executable to generate an orography
# file with a halo of 4 cells.
#
printf "%s %s %s %s %s\n" \
  $nx_T7 \
  $ny_T7 \
  $nh4_T7 \
  \'$WORKDIR_FLTR/oro.${CRES}.tile${tile}.nc\' \
  \'$WORKDIR_SHVE/${CRES}_oro_data.tile${tile}.halo${nh4_T7}.nc\' \
  > input.shave.orog.halo${nh4_T7}
#
#-----------------------------------------------------------------------
#
# Shave the grid and orography files.  Note that APRUN is defined dif-
# ferently for each machine.
#
#-----------------------------------------------------------------------
#
$APRUN $EXECDIR/$shave_exec < input.shave.grid.halo${nh3_T7} || \
print_err_msg_exit "\
Call to \"shave\" executable to generate grid file with a 3-cell wide
halo returned with nonzero exit code."

$APRUN $EXECDIR/$shave_exec < input.shave.grid.halo${nh4_T7} || \
print_err_msg_exit "\
Call to \"shave\" executable to generate grid file with a 4-cell wide
halo returned with nonzero exit code."

$APRUN $EXECDIR/$shave_exec < input.shave.orog.halo${nh0_T7} || \
print_err_msg_exit "\
Call to \"shave\" executable to generate (filtered) orography file with-
out a halo returned with nonzero exit code."

$APRUN $EXECDIR/$shave_exec < input.shave.orog.halo${nh4_T7} || \
print_err_msg_exit "\
Call to \"shave\" executable to generate (filtered) orography file with
a 4-cell wide halo returned with nonzero exit code."

print_info_msg_verbose "\
\"Shaving\" of regional grid and filtered orography files complete."
#
#-----------------------------------------------------------------------
#
# Add links in shave directory to the grid and orography files with 4-
# cell-wide halos such that the link names do not contain the halo 
# width.  These links are needed by the make_sfc_climo task (which uses
# the sfc_climo_gen code).
#
# NOTE: It would be nice to modify the sfc_climo_gen_code to read in
# files that have the halo size in their names.
#
#-----------------------------------------------------------------------
#
print_info_msg_verbose "\
Creating links needed by the make_sfc_climo task to the 4-halo grid and
orography files..."

cd_vrfy $WORKDIR_SHVE
ln_vrfy -sf ${CRES}_grid.tile${tile}.halo${nh4_T7}.nc \
            ${CRES}_grid.tile${tile}.nc
ln_vrfy -sf ${CRES}_oro_data.tile${tile}.halo${nh4_T7}.nc \
            ${CRES}_oro_data.tile${tile}.nc
#
#-----------------------------------------------------------------------
#
# For convenience (in later tasks), copy the mosaic file created in the 
# grid generation step above from the grid directory to the shave di-
# rectory (it's a very small file, so duplicate copies are ok).
#
#-----------------------------------------------------------------------
#
cp_vrfy $WORKDIR_GRID/${CRES}_mosaic.nc $WORKDIR_SHVE
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "\

========================================================================
Grid and filtered orography files with various halo widths generated 
successfully!!!
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1


