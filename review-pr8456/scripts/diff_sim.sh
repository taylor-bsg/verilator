#!/usr/bin/env bash
# Differential simulation: build and run the same design with two Verilator
# trees and compare simulation output, then print DFG sharing statistics.
#
# usage: BASE_ROOT=<built tree> PR_ROOT=<built tree> diff_sim.sh <tag> <src.v> [verilator flags...]
# e.g.:  diff_sim.sh mix_t4 ../designs/mix.v --threads 4
set -u
: "${BASE_ROOT:?set BASE_ROOT to a built baseline Verilator tree}"
: "${PR_ROOT:?set PR_ROOT to a built Verilator tree with the change}"
OUT=${OUT:-$PWD/out}
tag=$1
src=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
shift 2

for w in base pr; do
  root=$BASE_ROOT
  [ "$w" = pr ] && root=$PR_ROOT
  od=$OUT/${tag}_$w
  rm -rf "$od"
  mkdir -p "$od"
  if ! VERILATOR_ROOT=$root "$root/bin/verilator" --binary --timing --stats -Mdir "$od" \
      --prefix Vtop -j 4 "$@" "$src" > "$od/verilate.log" 2>&1; then
    echo "[$tag] $w: verilate/build FAILED, see $od/verilate.log"
    exit 1
  fi
  # Drop the wall-clock lines of the simulation report, they always differ
  (cd "$od" && ./Vtop 2>&1 | grep -vE "walltime|S i m u l a t i o n|Verilator: cpu" > sim.log
   echo "rc=${PIPESTATUS[0]}" >> sim.log)
done

b=$OUT/${tag}_base
p=$OUT/${tag}_pr
stat() { grep -hE "$2" "$1/Vtop__stats.txt" 2>/dev/null | awk '{print $NF}'; }
if cmp -s "$b/sim.log" "$p/sim.log" && grep -q 'All Finished' "$p/sim.log"; then
  res=SAME
else
  res=DIFFERENT
fi
printf "%-16s sim:%-9s reused=%-5s combined(base/pr)=%s/%s  __Vdfg-in-headers(base/pr)=%s/%s  flags: %s\n" \
  "$tag" "$res" "$(stat "$p" 'temporary declarations reused')" \
  "$(stat "$b" 'Combined CFuncs')" "$(stat "$p" 'Combined CFuncs')" \
  "$(cat "$b"/*.h | grep -c __Vdfg)" "$(cat "$p"/*.h | grep -c __Vdfg)" "$*"
