#!/usr/bin/env bash

# Synopsis:
# Build and run the tests without lake, which makes cold runs much faster.
# bin/run.sh calls this first and falls back to `lake test` if it fails.

# Arguments:
# $1: the prepared build directory (with Solution.lean, ExerciseTest.lean and Extra.lean)
# $2: path to output directory

# Output:
# Exits with 0 once the test executable has written results.json to the output directory.
# Exits with 1 on anything unexpected (a compile error, a warning, a crash), so that
# bin/run.sh can run `lake test` and report the error exactly as before.

# Why this is faster:
# On a machine with a cold page cache, most of a run goes on reading the toolchain
# from disk. `lake test` links the test executable statically, so the linker reads
# about 290 MB of static libraries (libLean.a alone is 340 MB). Here the executable is
# linked against libleanshared.so instead. The lean binary has just loaded that library,
# so the link reads almost nothing new. The compiled test code is the same as before.
# Calling lean and clang directly also skips lake's own start-up.

set -o pipefail

build_dir="$1"
output_dir="$2"
runner_dir=/opt/test-runner

# Find the toolchain from lean-toolchain directly, which skips the elan proxy.
# "leanprover/lean4:v4.29.0" is installed as "leanprover--lean4---v4.29.0".
toolchain_name=$(sed 's#/#--#; s#:#---#' "${runner_dir}/lean-toolchain")
toolchain="${ELAN_HOME:-/usr/local/elan}/toolchains/${toolchain_name}"
[ -x "${toolchain}/bin/lean" ] || exit 1

out="${build_dir}/.fast-build"
mkdir -p "${out}"
cd "${build_dir}" || exit 1

# LeanTest was built at image build. Its .olean files are only read, so they can be used in place.
export LEAN_PATH="${runner_dir}/.lake/build/lib/lean:${out}"

# These are the flags lake passes to clang for each module.
cflags=(
    -I "${toolchain}/include" -fstack-clash-protection -fdata-sections -ffunction-sections
    -fPIC -fvisibility=hidden -Wno-unused-command-line-argument --sysroot "${toolchain}"
    -nostdinc -isystem "${toolchain}/include/clang" -O3 -DNDEBUG -DLEAN_EXPORTING
)

# Lake only builds Extra when the solution or the tests import it.
modules="Solution ExerciseTest"
if grep -qE '^[[:space:]]*import[[:space:]]+Extra([[:space:]]|$)' Solution.lean ExerciseTest.lean; then
    modules="Extra ${modules}"
fi

# Compile each module in import order. Each module's C file is compiled in the
# background while lean elaborates the next module, as lake does.
objects=()
pids=()
for module in ${modules}; do
    lean_output=$("${toolchain}/bin/lean" -DwarningAsError=true "${module}.lean" \
        -o "${out}/${module}.olean" -i "${out}/${module}.ilean" -c "${out}/${module}.c" 2>&1) || exit 1
    # lake --wfail fails on any warning, so leave anything unusual to lake.
    printf '%s' "${lean_output}" | grep -qE '(^|: )(warning|error):' && exit 1
    ( "${toolchain}/bin/clang" -c -o "${out}/${module}.o" "${out}/${module}.c" "${cflags[@]}" \
        2> "${out}/${module}.clang.log" && [ ! -s "${out}/${module}.clang.log" ] ) &
    pids+=($!)
    objects+=("${out}/${module}.o")
done
for pid in "${pids[@]}"; do
    wait "${pid}" || exit 1
done

# Link as lake does, but against libleanshared.so in place of the static Lean libraries.
"${toolchain}/bin/clang" -o "${out}/ExerciseTest" "${objects[@]}" \
    "${runner_dir}"/.lake/build/ir/LeanTest/*.c.o.export "${runner_dir}/.lake/build/ir/LeanTest.c.o.export" \
    -L "${toolchain}/lib/lean" --sysroot "${toolchain}" -L "${toolchain}/lib" -L "${toolchain}/lib/glibc" \
    -lc -lc_nonshared -Wl,--as-needed -l:ld.so -Wl,--no-as-needed -lpthread_nonshared \
    -fuse-ld=lld -lleanshared -Wl,-rpath,"${toolchain}/lib/lean" -lm -ldl -pthread \
    > "${out}/link.log" 2>&1 || exit 1
[ -s "${out}/link.log" ] && exit 1

# LeanTest.runTestSuites writes results.json to EXERCISM_OUTPUT_DIR once all the tests have run.
# EXERCISM_TEST_FILE is used to capture `test_code`.
rm -f "${output_dir}/results.json"
EXERCISM_OUTPUT_DIR="${output_dir}" EXERCISM_TEST_FILE="${build_dir}/ExerciseTest.lean" \
    "${out}/ExerciseTest" > /dev/null 2>&1

[ -f "${output_dir}/results.json" ]
