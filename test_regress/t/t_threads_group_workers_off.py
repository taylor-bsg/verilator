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
test.top_filename = "t/t_threads_group_workers.v"
test.clean_objs()
test.write_wholefile(test.obj_dir + "/units.vlt", '''`verilator_config
threads_group -module "worker_tile"
''')
test.compile(verilator_flags2=[test.obj_dir + "/units.vlt", "--threads-group-list"], threads=2)
test.execute()
test.file_grep_count(test.obj_dir + "/" + test.vm_prefix + "__threads_groups.txt",
                     r'^"worker_tile"\t\d+\tauto\t"t\.g\[\d+\]\.u"\t"\*"$', 16)

# The same mapping file can be kept for serial builds, where units are ignored.
test.clean_objs()
test.compile(verilator_flags2=["t/t_threads_group_workers.vlt", "--threads-group-list"], threads=1)
test.execute()
assert not os.path.exists(test.obj_dir + "/" + test.vm_prefix + "__threads_groups.txt")
test.passes()
