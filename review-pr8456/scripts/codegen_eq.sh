#!/usr/bin/env bash
# Verilate a design with two Verilator trees and compare the generated C++
# after normalizing DFG temporary names and whitespace. Used to show that the
# makeNewVar refactor only changes temporary names (EmitC indentation depends
# on name length, hence the whitespace normalization).
#
# usage: A_ROOT=<tree> B_ROOT=<tree> codegen_eq.sh <tag> <src.v> [verilator flags...]
set -u
: "${A_ROOT:?set A_ROOT to a built Verilator tree}"
: "${B_ROOT:?set B_ROOT to a built Verilator tree}"
OUT=${OUT:-$PWD/out}
tag=$1
src=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
shift 2

for w in A B; do
  root=$A_ROOT
  [ "$w" = B ] && root=$B_ROOT
  od=$OUT/geq_${tag}_$w
  rm -rf "$od"
  mkdir -p "$od"
  VERILATOR_ROOT=$root "$root/bin/verilator" --cc --timing --stats -Mdir "$od" --prefix Vtop \
    "$@" "$src" > "$od/log" 2>&1 || { echo "[$tag] $w: verilate FAILED, see $od/log"; exit 1; }
done

norm() {
  cat "$1"/*.h "$1"/*.cpp | grep -vE '^//|Verilator [0-9]' \
    | sed -E 's/__Vdfg([A-Za-z_]+)_h[0-9a-f]+_[0-9]+_[0-9]+/__Vdfg\1_N/g' | tr -d ' \t\n'
}
if diff -q <(norm "$OUT/geq_${tag}_A") <(norm "$OUT/geq_${tag}_B") > /dev/null; then
  res=IDENTICAL
else
  res=DIFFERENT
fi
reused() { grep -hE 'declarations reused' "$1/Vtop__stats.txt" | awk '{print $NF}'; }
echo "$tag: normalized C++ A vs B: $res  (reused A=$(reused "$OUT/geq_${tag}_A") B=$(reused "$OUT/geq_${tag}_B"))"
