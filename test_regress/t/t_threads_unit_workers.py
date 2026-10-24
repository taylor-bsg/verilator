#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import re

import vltest_bootstrap

test.scenarios('vltmt')

prefix = test.vm_prefix
for count, expected in [(16, [1] * 8 + [0] * 8), (4, [1, 0, 1, 0])]:
    test.clean_objs()
    test.vm_prefix = prefix + f"_{count}"
    test.stats = f"{test.obj_dir}/{test.vm_prefix}__stats.txt"
    test.compile(verilator_flags2=[
        "t/t_threads_unit_workers.vlt", "--threads-unit-list", "--stats", f"-GN={count}",
        "-CFLAGS", "-DVL_THREADS_SERIAL_COST=0"
    ],
                 threads=2)
    test.execute()

    listing = test.file_contents(f"{test.obj_dir}/{test.vm_prefix}__threads_units.txt")
    rows = [line.split('\t') for line in listing.splitlines() if not line.startswith('#')]
    assert rows == [['"worker_tile"', str(i),
                     str(expected[i]), f'"t.g[{i}].u"'] for i in range(count)]
    test.file_grep(test.stats, r'MTask graph, explicitly placed units\s+(\d+)', count)

    # Inspect actual generated task dispatch, independently of the listing. Parameter variants
    # share one index space, and instance zero's absence from NBA must not renumber later units.
    code = '\n'.join(test.file_contents(path) for path in test.glob_some(test.obj_dir + '/*.cpp'))
    task_bodies = dict(
        re.findall(r'^void (\w+__nba_mtask\d+)\([^\n]+\) \{\n(.*?)^}', code, re.M | re.S))
    dispatch = re.findall(r'^void \w+____Vthread__nba__s\d+__t(\d+)\([^\n]+\) \{\n(.*?)^}', code,
                          re.M | re.S)
    seen = set()
    for worker, body in dispatch:
        for task in re.findall(r'\b(\w+__nba_mtask\d+)\(', body):
            for index in re.findall(
                    r'\(\(&vlSymsp->vlInst.TOP__t__DOT__g__BRA__(\d+)__KET____DOT__u\)\)',
                    task_bodies[task]):
                index = int(index)
                assert int(worker) == expected[index], (index, worker, expected[index])
                seen.add(index)
    assert seen >= set(range(1, count)), seen

test.extract(in_filename="t/t_threads_unit_workers.vlt",
             out_filename=test.root + "/docs/gen/ex_threads_unit_workers.rst",
             regexp=r'^(?!//)')
test.passes()
