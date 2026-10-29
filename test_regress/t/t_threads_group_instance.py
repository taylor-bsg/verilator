#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import re
import shlex

import vltest_bootstrap

test.scenarios('vltmt')


def scope_name(scope):
    for old, new in [('__DOT__', '.'), ('__BRA__', '['), ('__KET__', ']'), ('__', '.')]:
        scope = scope.replace(old, new)
    return scope


prefix = test.vm_prefix
for count, mode in [(12, ''), (4, '--flatten'), (4, '-fno-inline')]:
    test.clean_objs()
    test.vm_prefix = prefix + f"_{count}" + mode.replace('-', '_')
    test.stats = f"{test.obj_dir}/{test.vm_prefix}__stats.txt"
    flags = [
        "t/t_threads_group_instance.vlt", "--threads-group-list", "--stats", f"-GN={count}",
        "-CFLAGS", "-DVL_THREADS_SERIAL_COST=0"
    ]
    if mode:
        flags.append(mode)
    test.compile(verilator_flags2=flags, threads=2)
    test.execute()

    listing = test.file_contents(f"{test.obj_dir}/{test.vm_prefix}__threads_groups.txt")
    rows = [shlex.split(line) for line in listing.splitlines() if not line.startswith('#')]
    expected = {}
    for index in range(count):
        tile_worker = int(index >= 6) if count == 12 else index % 2
        expected[f't.g[{index}].island.tile'] = ('instance_tile', index, tile_worker, '*')
        expected[f't.g[{index}].island.io_rtr'] = ('instance_router', index, 1 - tile_worker,
                                                   'io_*')
    expected['t.diag'] = ('instance_router', 0, 0, 'diag')
    actual = {
        name: (module, int(index), int(worker), pattern)
        for module, index, worker, name, pattern in rows
    }
    assert actual == expected, (actual, expected)
    assert f'# Local instance "io_rtr" count {count}' in listing
    test.file_grep(test.stats, r'MTask graph, explicitly placed units\s+(\d+)', 2 * count + 1)

    # Verify dispatch independently of the reported assignments. Each tile's unselected router
    # must stay on the tile's owner, which is opposite the selected I/O router's owner.
    code = '\n'.join(test.file_contents(path) for path in test.glob_some(test.obj_dir + '/*.cpp'))
    task_bodies = dict(
        re.findall(r'^void (\w+__nba_mtask\d+)\([^\n]+\) \{\n(.*?)^}', code, re.M | re.S))
    dispatch = re.findall(r'^void \w+____Vthread__nba__s\d+__t(\d+)\([^\n]+\) \{\n(.*?)^}', code,
                          re.M | re.S)
    seen = set()
    for worker, body in dispatch:
        # The scheduler numbers the caller last; the configuration numbers it zero.
        worker = (int(worker) + 1) % 2
        for task in re.findall(r'\b(\w+__nba_mtask\d+)\(', body):
            for scope in re.findall(r'\(\(&vlSymsp->vlInst.TOP__(t__[A-Za-z_0-9]+)\)\)',
                                    task_bodies[task]):
                name = scope_name(scope)
                units = [unit for unit in expected if name == unit or name.startswith(unit + '.')]
                if units:
                    unit = max(units, key=len)
                    assert worker == expected[unit][2], (name, worker, expected[unit])
                    seen.add(unit)
    assert seen == set(expected), (seen, expected)
    symbols = test.file_contents(test.glob_one(test.obj_dir + '/*__Syms.h'))
    retained = [scope_name(scope) for scope in re.findall(r'\bTOP__(t__\w+)\s*;', symbols)]
    internal_routers = sum(name.endswith('.tile.rtr') for name in retained)
    assert internal_routers == (count if mode == '-fno-inline' else 0), retained

test.extract(in_filename="t/t_threads_group_instance.vlt",
             out_filename=test.root + "/docs/gen/ex_threads_group_instance.rst",
             regexp=r'^(?!//)')
test.passes()
