#!/usr/bin/env sh

# Synopsis:
# Run the test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: path to solution folder
# $3: path to output directory

# Output:
# Writes the test results to a results.json file in the passed-in output directory.
# The test results are formatted according to the specifications at https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md
# (interface version 3).

# Example:
# ./bin/run.sh two-fer path/to/solution/folder/ path/to/output/directory/

# If any required argument is missing, print the usage and exit
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "usage: ./bin/run.sh exercise-slug path/to/solution/folder/ path/to/output/directory/"
    exit 1
fi

slug="$1"
solution_dir=$(realpath "${2%/}")
output_dir=$(realpath "${3%/}")
results_file="${output_dir}/results.json"

# Create the output directory if it doesn't exist
mkdir -p "${output_dir}"

echo "${slug}: testing..."

# Copy solution to a writable temp directory (lake needs to write build files)
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

words=$(echo "$slug" | tr '-' ' ')
pascal_slug=""
for word in $words; do
    rest_of_word="${word#?}"
    first_char=$(echo "${word%${rest_of_word}}" | tr '[:lower:]' '[:upper:]')
    pascal_slug="${pascal_slug}${first_char}${rest_of_word}"
done

cp -r "${solution_dir}/." "${tmp_dir}"
if [ -f "${solution_dir}/Extra.lean" ]; then
    cp "${solution_dir}/Extra.lean" "${tmp_dir}/Extra.lean"
else
    touch "${tmp_dir}/Extra.lean"
fi
rm "${tmp_dir}/lakefile.toml"
mv "${tmp_dir}/${pascal_slug}.lean" "${tmp_dir}/Solution.lean"
mv "${tmp_dir}/${pascal_slug}Test.lean" "${tmp_dir}/ExerciseTest.lean"
sed -i "s/[[:space:]]*import[[:space:]]\+${pascal_slug}/import Solution/g" "${tmp_dir}/ExerciseTest.lean"

cp -r "/opt/test-runner/." "${tmp_dir}"

cd "${tmp_dir}"

# LeanTest.runTestSuites writes results.json directly to EXERCISM_OUTPUT_DIR
# EXERCISM_TEST_FILE is used to capture `test_code`
export EXERCISM_OUTPUT_DIR="${output_dir}"
export EXERCISM_TEST_FILE="${tmp_dir}/ExerciseTest.lean"

# Run the tests and capture output to be used in case of compile-error
test_output=$(lake --wfail test 2>&1)

# results.json is written already formatted by LeanTest once the test binary runs to completion
if [ ! -f "${results_file}" ]; then
    # No results.json may indicate a compile-time error
    # We check if there is an error message and extract it from the captured output
    cleaned=$(printf '%s\n' "${test_output}" | awk '
        /^error:/ { capture=1 }
        /^(✔|✖|trace:|info:|Some required targets|error: (Lean exited|build failed))/ { capture=0 }
        capture { print }
    ' | sed "s#${tmp_dir}/##g")
    if [ -z "${cleaned}" ]; then
        cleaned="No tests were executed"
    fi
    jq -n --arg msg "${cleaned}" '{version: 3, status: "error", message: $msg}' > "${results_file}"
fi

echo "${slug}: done"
