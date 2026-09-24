# Review of verilator/verilator#8456 — share DFG temporary declarations

Independent review notes, prepared with Claude Code (Opus 5.5), for
cross-checking. **This folder is review material only: drop the commit that
adds it before merging or running the `t_dist_*` tests** (the files have no
distribution headers).

- Reviewed: PR head `0815670c5` (one commit), base `26dd04c02`.
- Machine: Apple M5 Max (6 + 12 cores, 128-byte cache lines, 192 KB L1i),
  macOS 26.4, Apple clang. All timings below are from this machine.

## Commits on this branch (on top of `0815670c5`)

1. `Internals: Remove sequence number argument from DfgGraph::makeNewVar`
   — answers gezalore's latest review comment.
1. `Tests: run t_dfg_temp_sharing with -fno-gate` — makes the test's
   self-checks observe the shared declarations.
1. `Tests: cover BreakCycles TraceDriver temporary creation` — covers the
   one patch line that upstream coverage reports as unexecuted.
1. This folder (not for merge).

## Summary

The sharing scheme is correct as far as I could determine: code audit,
differential simulation against the baseline, and mutation testing found no
problem. Open items, most important first:

1. Without the separate "write-aware layout" change, this PR makes
   multithreaded models 3–8% slower on a benchmark of the shape wsnyder
   suggested (single-threaded is about 2% faster). The cause is data layout,
   not function combining.
1. gezalore's `n` comment is valid as a design point (not a bug). Commit 1.
1. The PR's test cannot detect the bug class it describes, because V3Gate
   inlines every temporary. Commit 2.
1. Upstream coverage is 18 of 19 changed lines; the missing line is never
   reached by any test. Commit 3.

## Findings

### 1. gezalore's comment: `n` in `makeNewVar` (commit 1)

In the PR, `makeNewVar(flp, prefix, n, dtype, scopep)` uses `n` only when it
creates a new declaration, and ignores it when it reuses a slot.

- **Not a correctness bug.** Names are only generated for new declarations,
  and each of those uses one of the caller's `(prefix, n)` pairs, which are
  unique per graph, so names cannot collide. Example from
  `t_dfg_temp_sharing.v -fno-gate`: each of the 4 parameterized modules has 4
  instances; the PR emits declarations numbered 0–7, and the values 8–31
  computed by callers are discarded.
- **But `n` is redundant.** The allocator knows exactly when it creates a
  declaration, so it can number declarations itself. Every counter below
  existed only to produce `n`, and commit 1 removes them all:
  - Regularize `m_nTmps`, Peephole `m_nTemps`, BinToOneHot `nTables`
  - Synthesize `m_nUnpack`, `m_nPathPred`, `m_nBranchCond`, and the
    `AstVar::user3` counter with its `VNUser3InUse`
  - BreakCycles' `AstNetlist::user2` counter with its `VNUser2InUse`
- `makeUniqueName` becomes private (its only caller is now `makeNewVar`).
- The `makeNewVar` comment now states the invariant the sharing depends on
  (see finding 5).

Verification of commit 1:

- Builds warning-free with `-W -Wall -Wextra -Werror` (debug configuration),
  clang-format-18 clean.
- Generated C++ identical to the PR after normalizing temporary names and
  whitespace (EmitC indentation depends on name length) on 7 design/option
  combinations, including `--threads 4`, with identical
  "temporary declarations reused" counts (`scripts/codegen_eq.sh`).
- All `t_dfg*` tests pass (vlt + vltmt).

### 2. Multithreaded slowdown without the layout change

Benchmark: `designs/genbench.py 64 48 16000 512` — 64 identical instances of
a 48-stage, 512-bit datapath with little cross-instance communication.
PR/baseline ratio of median wall time (below 1 means the PR is faster):

| run | 1 thread | 2 | 4 | 6 | 8 |
|---|---|---|---|---|---|
| A: 9 reps | 0.975 | 1.042 | 1.046 | 1.080 | 0.994\* |
| B: 11 reps, same models as A | 0.978 | – | 1.043 | 1.057 | – |
| C: `-fno-combine`, 9 reps | 0.986 | – | 1.030 | 1.058 | – |
| D: regenerated models, 7 / 15 reps | 0.982 | – | 1.034 / 1.031 | 1.032 (15 reps) | – |

\* 8 threads is slower than 6 threads on this machine (efficiency cores),
so that column is not meaningful.

Repetitions were interleaved, and minimum times tracked the medians except
for one noisy 6-thread run (7 reps in D, not shown).

- The slowdown remains with `-fno-combine` (run C), so it comes from the data
  layout, not from function combining. For `--threads 4`, V3VariableOrder's
  per-MTask affinity groups drop from 126 to 61, and the instance class
  shrinks from 802 to 174 members. This is consistent with wsnyder's
  false-sharing concern and with the author's own observation in the PR
  thread.
- gezalore asked for the related changes as "pre-PRs", so the layout change
  should land first, and this PR should state the dependency.
- The upstream RTLmeter numbers in the PR thread are for the first
  (Regularize-only) version. The RTLmeter run for `0815670c5` was still in
  progress when these notes were written. The first-version run is also
  worth checking: single-threaded gcc showed XiangShan default-chisel6 at
  0.85–0.88× on all three of its workloads (possibly a slow runner).

### 3. The new test's self-checks cannot see the shared declarations (commit 2)

With default options, V3Gate inlines all 32 DFG temporaries in
`t_dfg_temp_sharing.v`. The generated C++ is identical to the baseline (after
normalizing names), so the self-checks never exercise shared storage.

- `mutant-alias-slots.patch` ignores the per-scope slot counter, so
  temporaries within one instance alias the same declaration. The PR's test
  still passes simulation with it; only the exact count fails (28 vs 24).
- With `-fno-gate` (commit 2) the temporaries survive into the model:
  - the mutant fails the self-check:
    `got=12a409daf exp=22aa9daf (comb0 !== expected0)`
  - `Combined CFuncs` goes 0 (baseline) → 12, which demonstrates the benefit
    the PR is for
  - `__Vdfg` class members go 32 → 8.
- `designs/mix.v` also detects the mutant, even with default options.

### 4. Coverage blocker (commit 3)

Upstream patch coverage for `0815670c5` is 18 of 19 lines. The unexecuted
line is `V3DfgBreakCycles.cpp:247`, the `makeNewVar` call in
`TraceDriver::createTmp`, which no test reaches (an existing gap that the
signature change exposed).

How the path is reached: `TraceDriver` creates a temporary when a traced
`DfgSplicePacked` lies outside the component being fixed and there is no
default driver. `visit(DfgSpliceArray)` clears the default driver before
tracing an element's packed splice, so the recipe is:

- an unpacked array in a variable-level cycle through another element, where
- the element being read is driven in pieces **with a gap** — fully covering
  pieces get coalesced into a `DfgConcat` during synthesis.

`designs/tracedriver_min.v` is the minimal form. Commit 3 adds the same case
to `t_dfg_break_cycles.v`, inside its reference-vs-optimized harness. With a
temporary print in `createTmp`, the new case reaches it twice. It passes on
the baseline, the PR, and commit 1, in vlt and vltmt.

### 5. Implicit invariant: same prefix ⇒ same `AstVar` attributes

Slots are keyed by (module, prefix, data type), so every temporary created
with the same prefix may share one `AstVar`. Correctness therefore requires
callers to set identical `AstVar` attributes for a given prefix.

Real example: BinToOneHot's `Pre` temporary calls `setIgnoreSchedWrite()` on
the `AstVar`, and the scheduler (`V3Sched*`, `V3Order*`) reads that flag per
`AstVar`. If a `Pre` declaration were ever pooled with another kind of
temporary, the scheduler would ignore writes to that temporary in other
instances.

Today every prefix is used consistently, so this is safe. Commit 1 documents
the rule at `makeNewVar`; a debug assertion would be stronger.

### 6. Minor

- Sharing only happens within one `DfgGraph`. BinToOneHot and Peephole
  temporaries are created on per-component graphs after `splitIntoComponents`,
  so they are rarely shared. DFG also places many per-instance temporaries in
  the parent scope, because it sees through port connections: in
  `designs/mix2.v`, 7 of 8 decoder tables landed in the root scope.
  Hoisting the allocator into `V3DfgContext` (one per DFG run) would share
  across graphs, and would let the statistic live with the other DFG
  statistics instead of in `~DfgGraph`.
- The statistic name "Optimizations, DFG, temporary declarations reused"
  doesn't follow the usual "Optimizations, DFG, <Pass>, <what>" pattern.
  Emitting it from `~DfgGraph` is harmless, because `addStatSum` ignores zeros.
- The PR description's "simultaneously live temporaries ... distinct slots"
  implies liveness analysis; there is none. Every temporary of an instance
  gets its own slot.
- Slots are matched across instances by creation order. When instances
  diverge (for example through constant folding), logically different
  temporaries can share a declaration. That is still correct, but it gives
  V3Combine fewer identical functions to merge.

## Correctness audit

Places where sharing one `AstVar` between several `AstVarScope`s could have
broken something, and why each is fine. References are to the PR head.

- **DFG never deletes a shared declaration.** `removeUnobservable`
  (V3DfgPasses.cpp), Regularize `eliminateVars` and Peephole push only
  `varp->vscp()` (the per-scope `AstVarScope`) into `m_deleteps`, and
  V3DfgContext.h deletes only those. So `m_declps` never dangles and no other
  instance loses its declaration.
- **DFG never renames, retypes or unlinks a temporary's `AstVar`.**
- **Per-variable DFG reference flags** (`hasExtRdRefs`, `hasDfgRefs`, ...)
  live in `AstVarScope::user1` (V3DfgVertices.h), i.e. per scope.
- **V3Localize** already expects shared `AstVar`s: "Leave the Var for now, as
  not all VarScopes referencing this Var might be localized". It creates a
  fresh local variable per function.
- **V3Const constant-assign folding** writes `isConst`/`valuep` onto the
  `AstVar`, but is guarded by `!varrefp->varScopep()` ("each scope may have
  different initial val."), so it never fires on scoped DFG temporaries.
- **V3Dead** reference-counts `AstVar`s through `AstVarScope`s and `VarRef`s.
- **V3OrderMTaskFixHazards** tracks hazards per `AstVarScope`.
- **Tracing**: trace declarations are made before DFG, so DFG temporaries are
  not traced, even with `--trace-underscore`.
- **Determinism**: the pointer-keyed maps are only used for lookups. Output
  was byte-identical across repeated runs.

## Verification performed

- New test passes (vlt + vltmt, 24 reuses). All 40 `t_dfg*` tests pass on
  macOS/Apple clang (1 skipped: needs SystemC).
- **Differential simulation** against the baseline (`scripts/diff_sim.sh`),
  with identical output in every case:
  - `designs/mix.v` — every temporary kind, constant-tied instances,
    cross-instance dataflow — with 9 option sets: default, `--threads 4`,
    `-fno-gate`, `-fno-gate -fno-localize`, `--threads 4 -fno-gate`,
    `--x-initial unique --x-assign unique`, `-O3`, `-fno-combine`,
    `--trace-vcd --trace-underscore`
  - `designs/mix2.v` — BinToOneHot and BreakCycles
  - `t_dfg_temp_sharing.v -fno-gate`
  - benchmark output hashes at 1, 2, 4, 6 and 8 threads.
- **Targeted regression on commits 1–3**: 1,101 passed, 12 skipped, 4 failed.
  The failures are `t_order_clkinst` and `t_split_var_2_trace` (vlt + vltmt),
  which fail identically on the unmodified baseline on this machine: VCD
  identifier codes differ and `vcddiff` is not installed. The suites run were
  `t_dfg*`, `t_opt*`, `t_inst*`, `t_gen*`, `t_unopt*`, `t_split*`, `t_order*`,
  `t_gate*`, `t_hier_block*`, `t_threads*`, `t_alw*`, `t_array*`, `t_clk*`,
  `t_interface*`.
- **Upstream CI on `0815670c5`**: Regression passed; coverage 18 of 19 lines;
  RTLmeter pending.

## Other measurements

| design (`genbench.py` args) | `.text` base → PR | `__Vdfg` members | Combined CFuncs |
|---|---|---|---|
| `32 24 2000` (64-bit) | 298 KB → 190 KB (−36%) | 96 → 3 | 94 → 125 |
| `64 64 20000` (64-bit) | 1.04 MB → 0.40 MB (−61%) | 768 → 12 | 190 → 253 |
| `64 48 16000 512` | 12.0 MB → 2.3 MB (−81%) | 704 → 11 | 190 → 253 |
| `64 48 16000 512`, `-fno-combine` | 12.2 MB → 12.1 MB | 704 → 11 | – |

- The code-size reduction comes entirely from V3Combine (last row).
- Verilator itself, on the 512-bit design: peak memory 2.0–2.1 GB → 1.4–1.5 GB,
  verilation time 5.2–5.4 s → 4.1 s; DFG stage time unchanged.
- Very small configurations (e.g. `16 12 2000`) show no difference, because
  every temporary gets localized or inlined anyway.

## Reproducing

Build two trees: the baseline (`26dd04c02`) and this branch (or the PR head).

- GNU Make refuses directories containing spaces.
- `make verilator_exe` avoids needing help2man.
- The test driver needs Python ≥ 3.10 with the `distro` module.

```sh
export BASE_ROOT=/path/to/verilator-base PR_ROOT=/path/to/verilator-pr
cd review-pr8456/scripts

./diff_sim.sh mix ../designs/mix.v
./diff_sim.sh mix_t4 ../designs/mix.v --threads 4
./diff_sim.sh mix2 ../designs/mix2.v

python3 ../designs/genbench.py 64 48 16000 512 > wide.v
./bench.py wide wide.v 9 1,2,4,6
./bench.py wide_nocomb wide.v 9 1,4,6 -fno-combine

# Commit 1 vs the PR head: identical generated C++ modulo temp names
A_ROOT=/path/to/pr-head B_ROOT=/path/to/this-branch ./codegen_eq.sh mix ../designs/mix.v --threads 4
```

Mutation check: apply `mutant-alias-slots.patch` to the PR head, rebuild,
then run `t_dfg_temp_sharing` with and without commit 2's `-fno-gate`.

Caveats:

- One machine with heterogeneous cores; the benchmark is synthetic.
- The RTLmeter run for this revision is the authoritative performance check.
