#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import os
import shlex

import vltest_bootstrap

test.scenarios('vltmt')
test.top_filename = "t/t_threads_unit_instance.v"
test.clean_objs()
config = test.obj_dir + "/units.vlt"
test.write_wholefile(
    config, '''`verilator_config
threads_unit -module "instance_router" -instance "probe.dot"
threads_unit -module "instance_router" -instance "arr_rtr*"
threads_unit -module "instance_router" -instance "io_*"
threads_unit -module "instance_tile"
threads_unit -module "t" -instance "missing*"
''')
test.compile(verilator_flags2=[config, "--threads-unit-list", "-GN=4"], threads=2)
test.execute()
listing = test.file_contents(f"{test.obj_dir}/{test.vm_prefix}__threads_units.txt")
rows = [shlex.split(line) for line in listing.splitlines() if not line.startswith('#')]
assert len(rows) == 11, rows
assert all(row[2] == 'auto' for row in rows)
array_rows = [row for row in rows if row[4] == 'arr_rtr*']
assert [(row[1], row[3]) for row in array_rows] == [('0', 't.arr_rtr[1]'), ('1', 't.arr_rtr[2]')]
assert [row[3] for row in rows if row[4] == 'probe.dot'] == ['t.probe.dot']
assert sum(row[4] == 'io_*' for row in rows) == 4

# A module metacomment still marks every instance; a selector can place just a subset.
test.clean_objs()
test.vm_prefix += "_metacomment"
test.write_wholefile(
    config, '''`verilator_config
threads_unit -module "instance_router" -instance "io_*" -workers 4->2: { 1 0 1 0 }
''')
test.compile(verilator_flags2=[config, "--threads-unit-list", "-GN=4", "+define+ROUTER_UNIT"],
             threads=2)
test.execute()
listing = test.file_contents(f"{test.obj_dir}/{test.vm_prefix}__threads_units.txt")
rows = [shlex.split(line) for line in listing.splitlines() if not line.startswith('#')]
assert len(rows) == 12, rows
assert sum(row[2] == 'auto' for row in rows) == 8
assert [row[2] for row in rows if row[4] == 'io_*'] == ['1', '0', '1', '0']

# Selection and mapping are ignored for a serial build, including a nonmatching selector.
test.clean_objs()
test.vm_prefix += "_serial"
test.write_wholefile(
    config, '''`verilator_config
threads_unit -module "instance_router" -instance "missing*" -workers 1->2: { 0 }
''')
test.compile(verilator_flags2=[config, "--threads-unit-list", "-GN=4"], threads=1)
test.execute()
assert not os.path.exists(f"{test.obj_dir}/{test.vm_prefix}__threads_units.txt")
test.passes()
