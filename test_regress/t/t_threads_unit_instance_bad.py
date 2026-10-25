#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import os

import vltest_bootstrap

test.scenarios('vltmt')
test.top_filename = "t/t_threads_unit_instance.v"

cases = {
    'nomatch': 'threads_unit -module "instance_router" -instance "missing*"',
    'overlap': '''threads_unit -module "instance_router" -instance "io_*"
threads_unit -module "instance_router" -instance "io_rtr"''',
    'count':
    'threads_unit -module "instance_router" -instance "io_*" -workers 5->2: { 0 0 1 1 1 }',
}
for name, config in cases.items():
    test.clean_objs()
    filename = test.obj_dir + "/units.vlt"
    test.write_wholefile(filename, '`verilator_config\n' + config + '\n')
    test.compile(verilator_flags2=[filename, "-GN=4"],
                 threads=2,
                 fails=True,
                 expect_filename=f"t/t_threads_unit_instance_{name}_bad.out")

# A directory at the output path exercises the listing's file-open diagnostic.
test.clean_objs()
os.mkdir(f"{test.obj_dir}/{test.vm_prefix}__threads_units.txt")
test.compile(verilator_flags2=["--threads-unit-list", "-GN=4"],
             threads=2,
             fails=True,
             expect_filename="t/t_threads_unit_instance_list_bad.out")
test.passes()
