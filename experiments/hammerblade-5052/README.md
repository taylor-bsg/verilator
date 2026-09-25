# HammerBlade progress-protocol handoff to Linux

Experimental branch `taylor-bsg/verilator:codex/threads-progress-5052-hammerblade`.
This preserves the exact prototype measured on Mac, based on **Verilator 5.052**
(`ea338be98e1e838d3518809ce8899f85a009963c`), not current master. It is default-off,
not an upstream PR or a production-baseline recommendation. No unrelated DFG,
variable-layout, context-race, RTL, or application changes are included.

## What is published

- The actual implementation and two self-checking regression drivers, in the
  ordinary Verilator source/test locations. `--threads-progress` selects the
  prototype; `--no-threads-progress` selects the existing implementation.
- [Compact comparison](mac/comparison.json), [primary trial table](mac/results-table.md),
  [all 24 measured/warmup records](mac/measurements.json), copied timing files,
  marker CSVs and exact Mac command records under `mac/trials/`.
- [Source identities](provenance.json), [input identities](mac/inputs.json),
  [environment audit](mac/audit.json), and checksums in `SHA256SUMS`.
- [Task-local Replicant guard patch](replicant-experiment.patch), allowing only
  one/five-worker Proc+Endpoint builds in a private checkout.
- [Handbook contribution patch](handbook.patch), based on hb_handbook `18eacca`.
  It contains the reusable measurement lesson and compact results; it is not
  applied to any shared handbook branch by this publication.

Native Mac executables, full stdout logs, general host-process snapshots and
the multi-directory build cache are deliberately not committed. Stdout hashes
and correctness excerpts are retained. Paths beginning `/Users/pai/` are
historical provenance, **not Linux-accessible artifact locations**. The source
changes match the tested working files byte-for-byte. Publication checks only
identity/packaging; it does not claim a fresh build or Linux qualification.

## Result to reproduce: no PGO

Physical **16x8**, Proc+Endpoint hierarchy, 32 blocking 32-KiB cache banks,
iPoly=1, `pod_X1Y1_ruche_X16Y8_hbm_one_pseudo_channel`; Apple Clang 21, M5 Max.
Fast code `-O2 -march=native`, cold code unoptimized, support `-Os`.

| Whole-process mean wall time | One worker | Five, counters | Five, progress | Overall progress speedup |
|---|---:|---:|---:|---:|
| PageRank wiki-Vote, pod 36 | 25.860 s | 23.423 s | 23.130 s | 1.118x |
| AES NUM-ITER_2 | 75.140 s | 67.220 s | 66.050 s | 1.138x |

Incremental progress/padding wall reductions: **1.25% / 1.74%**. Three PageRank
and two AES trials per mode, not broad statistical evidence. All 24 runs passed;
15 are primary. All six original AES measurements were preserved but excluded
after a display-sleep transition; the complete six-position block was repeated
with display and system held awake. See the audit for the precise selection.
Five progress workers consumed about 3.92x/3.86x aggregate CPU time; that is not
an energy measure. Core placement/frequency were not controlled.

The separately collected **PGO-tuned** 5.052 results remain secondary:
3.64%/3.66% incremental reduction, 1.252x/1.290x overall speedup. They are not an
interleaved PGO-on/off experiment and cannot isolate cross-day host effects.
Do not mix older 5.050 results into either baseline.

## Mechanism and correctness scope

The compiler lowers cross-worker dependencies after static task placement.
Each producer lane publishes a release-store progress ordinal; consumers
acquire-load the largest required ordinal from each producer lane. State is
per model and schedule, padded to separate writers. The existing final join is
retained to prevent an epoch from lapping a waiter. Task bodies and lane order
are unchanged between the five-worker counter/progress models. This measures
protocol plus padding together, not either component independently.

Existing Mac qualification: 18 focused executions covering the protocol/model
fixtures, lifecycle, protected identifiers/C++14, one worker, existing thread/DPI/
hierarchy/PGO paths, TSan, and ASan/UBSan. **Not the full upstream regression.**
The fixtures serialize context construction/destruction and worker startup to
avoid a separately observed stock-5.052 global-context race; model evaluation
remains concurrent. This branch does not fix that independent context race.

## Linux launch instructions

Use an isolated clone, not a shared installed Verilator. Build with the already
qualified Linux compiler and dependencies; compare all modes with the same
compiler. Example, from the fresh clone root:

```sh
git clone --branch codex/threads-progress-5052-hammerblade \
  https://github.com/taylor-bsg/verilator.git verilator-progress-5052
cd verilator-progress-5052
autoconf
./configure --enable-ccwarn CC=clang CXX=clang++
make -j8
export VERILATOR_ROOT="$PWD"
cd test_regress
python3 driver.py --vltmt --jobs 2 --debug --obj-suffix linux-progress \
  t/t_threads_progress.py t/t_threads_progress_off.py
```

Run under the host's documented Linux setup/venv. Neither `caffeinate` nor Mac
host `.so` files belong in a Linux run. The commands above are handoff instructions,
not a claim they were executed on Linux in this publication.

Keep these source identities for the first matched comparison:

| Repository | Revision |
|---|---|
| bsg_bladerunner | `6b33a79d2cf356a91e9b920df83037aa07c29cf6` |
| bsg_replicant | `06997a3cc8ec48243538d3b307bf1e345bdb25b5` |
| bsg_manycore | `0052ce8594864befae2b85d55193706c88b14584` |
| basejump_stl | `fa07b1f180d0d313e15dc828249eea07b341852b` |
| DRAMSim3 | `0bd141a8d6b606e11c2aea6cf605a62853c60e74` |
| HardFloat | `5b7d5fe2df7e297b5ba095b3eb8a9517dc2e9d88` |

Reuse KK6's existing matched device ELF/data where hashes agree with
`mac/inputs.json`; its host shared objects must be Linux builds. The earlier
KK6 matched-input handoff was at
`/home/mbt/Documents/Codex/2026-09-17/welcome-to-kk6-it-is-a/kk6-mac-handoff.tar.gz`.
That path is a locator, not confirmation it is still present. Do not overwrite
existing checkouts or results. If any pin/input differs, record that explicitly.

For the model build, the relocatable [platform.mk](platform.mk) keeps the measured
wrapper structure but makes local roots explicit. Its Linux adaptation is not
yet executed. Define absolute `EXP_VR`, `EXP_INFRA`, `EXP_OUT` paths; place a
private pinned Replicant checkout at `$EXP_OUT/bsg_replicant`. Build it serially
with respect to other builds because its support libraries are shared by the
three model variants. Apply the guard only there:

```sh
git -C "$EXP_OUT/bsg_replicant" apply --check \
  "$EXP_VR/experiments/hammerblade-5052/replicant-experiment.patch"
git -C "$EXP_OUT/bsg_replicant" apply \
  "$EXP_VR/experiments/hammerblade-5052/replicant-experiment.patch"

make -j6 -f "$EXP_VR/experiments/hammerblade-5052/platform.mk" \
  TASK_ROOT="$EXP_OUT" MERGED_ROOT="$EXP_INFRA" \
  EXPERIMENT_VERILATOR_ROOT="$EXP_VR" CC=clang CXX=clang++ \
  MODEL_VARIANT=one VERILATOR_THREADS=1 VERILATOR_HIERARCHY=processor \
  VERILATOR_OPT_FAST='-O2 -march=native' VERILATOR_OPT_SLOW= \
  VERILATOR_OPT_GLOBAL=-Os \
  EXPERIMENT_VFLAGS='--stats --no-prof-pgo --no-threads-progress' sim-exec
```

Repeat the same build command with `MODEL_VARIANT=counter VERILATOR_THREADS=5`,
then with `MODEL_VARIANT=progress VERILATOR_THREADS=5` and
`EXPERIMENT_VFLAGS='--stats --no-prof-pgo --threads-progress'`. The resulting
paths are `$EXP_OUT/models/{one,counter,progress}/exec/simsc`. Do not provide a
runtime `profile.vlt` or manual processor-cost file; retain automatically
generated static child cost annotations. No hardware profiling model is needed.

Finish all builds before timing. Use serial runs with fresh writable directories,
one PageRank warmup per mode, three balanced PageRank trials and two reversed-order
AES trials per mode. Existing `mac/trials/**/command.json` files give literal
argument order; substitute Linux simulator, host `.so`, device ELF and input
paths. Wrap each launch in `/usr/bin/time -p`, retaining stdout/stderr and times
separately. Record compiler, CPU/socket placement, power settings and contention.
Validate normal correctness and all 128 ordered tile-marker pairs:

- PageRank absolute cycles 205449/219946, envelope 14,497, summed spans 1,831,112.
- AES absolute cycles 280611/668787, envelope 388,176, summed spans 49,638,787.

Compare identical untuned five-worker task bodies and lane order before attributing
timing differences to synchronization. Native wall time covers initialization,
kernel, checking and teardown; target cycles are correctness invariants. A Linux
speedup remains to be measured; the Mac ratios are not a prediction.
