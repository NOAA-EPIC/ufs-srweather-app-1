#!/usr/bin/env python3

import os
import unittest
from datetime import datetime, timedelta

from python_utils import (
     import_vars,
     set_env_var,
     print_input_args,
     load_config_file,
     flatten_dict,
)


def set_gridparams_ESGgrid(lon_ctr, lat_ctr, nx, ny, halo_width, delx, dely, pazi):
    """Sets the parameters for a grid that is to be generated using the "ESGgrid"
    grid generation method (i.e. GRID_GEN_METHOD set to "ESGgrid").

    Args:
        lon_ctr
        lat_ctr
        nx
        ny
        halo_width
        delx
        dely
        pazi
    Returns:
        Tuple of inputs, and 4 outputs (see return statement)
    """

    print_input_args(locals())

    # get constants
    IMPORTS = ["RADIUS_EARTH", "DEGS_PER_RADIAN"]
    USHdir = os.path.dirname(os.path.abspath(__file__))
    constants_cfg = load_config_file(os.path.join(USHdir,"constants.yaml"))
    import_vars(dictionary=flatten_dict(constants_cfg), env_vars=IMPORTS)

    #
    # -----------------------------------------------------------------------
    #
    # For a ESGgrid-type grid, the orography filtering is performed by pass-
    # ing to the orography filtering the parameters for an "equivalent" glo-
    # bal uniform cubed-sphere grid.  These are the parameters that a global
    # uniform cubed-sphere grid needs to have in order to have a nominal
    # grid cell size equal to that of the (average) cell size on the region-
    # al grid.  These globally-equivalent parameters include a resolution
    # (in units of number of cells in each of the two horizontal directions)
    # and a stretch factor.  The equivalent resolution is calculated in the
    # script that generates the grid, and the stretch factor needs to be set
    # to 1 because we are considering an equivalent globally UNIFORM grid.
    # However, it turns out that with a non-symmetric regional grid (one in
    # which nx is not equal to ny), setting stretch_factor to 1 fails be-
    # cause the orography filtering program is designed for a global cubed-
    # sphere grid and thus assumes that nx and ny for a given tile are equal
    # when stretch_factor is exactly equal to 1.
    # ^^-- Why is this?  Seems like symmetry btwn x and y should still hold when the stretch factor is not equal to 1.
    # It turns out that the program will work if we set stretch_factor to a
    # value that is not exactly 1.  This is what we do below.
    #
    # -----------------------------------------------------------------------
    #
    stretch_factor = 0.999  # Check whether the orography program has been fixed so that we can set this to 1...
    #
    # -----------------------------------------------------------------------
    #
    # Set parameters needed as inputs to the regional_grid grid generation
    # code.
    #
    # -----------------------------------------------------------------------
    #
    del_angle_x_sg = (delx / (2.0 * RADIUS_EARTH)) * DEGS_PER_RADIAN
    del_angle_y_sg = (dely / (2.0 * RADIUS_EARTH)) * DEGS_PER_RADIAN
    neg_nx_of_dom_with_wide_halo = -(nx + 2 * halo_width)
    neg_ny_of_dom_with_wide_halo = -(ny + 2 * halo_width)
    #
    # -----------------------------------------------------------------------
    #
    # return output variables.
    #
    # -----------------------------------------------------------------------
    #
    return {
        "LON_CTR": lon_ctr,
        "LAT_CTR": lat_ctr,
        "NX": nx,
        "NY": ny,
        "PAZI": pazi,
        "NHW": halo_width,
        "STRETCH_FAC": stretch_factor,
        "DEL_ANGLE_X_SG": del_angle_x_sg,
        "DEL_ANGLE_Y_SG": del_angle_y_sg,
        "NEG_NX_OF_DOM_WITH_WIDE_HALO": int(neg_nx_of_dom_with_wide_halo),
        "NEG_NY_OF_DOM_WITH_WIDE_HALO": int(neg_ny_of_dom_with_wide_halo),
    }


class Testing(unittest.TestCase):
    def test_set_gridparams_ESGgrid(self):

        grid_parms = set_gridparams_ESGgrid(
            lon_ctr=-97.5,
            lat_ctr=38.5,
            nx=1748,
            ny=1038,
            pazi=0.0,
            halo_width=6,
            delx=3000.0,
            dely=3000.0,
        )

        self.assertEqual(
            list(grid_parms.values()),
            [
                -97.5,
                38.5,
                1748,
                1038,
                0.0,
                6,
                0.999,
                0.013489400626200717,
                0.013489400626200717,
                -1760,
                -1050,
            ],
        )

    def setUp(self):
        set_env_var("DEBUG", False)
        set_env_var("VERBOSE", False)
