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

# Example:
# ./bin/run.sh two-fer path/to/solution/folder/ path/to/output/directory/

# If any required arguments is missing, print the usage and exit
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

words=$(echo "$slug" | tr '-' ' ')
pascal_slug=""
for word in $words; do
    first_char=$(echo "$word" | cut -c1 | tr '[:lower:]' '[:upper:]')
    rest_of_word=$(echo "$word" | cut -c2-)
    pascal_slug="${pascal_slug}${first_char}${rest_of_word}"
done

cp -r "${solution_dir}/." "${tmp_dir}"
rm "${tmp_dir}/lakefile.toml"
mv "${tmp_dir}/${pascal_slug}.lean" "${tmp_dir}/Solution.lean"
mv "${tmp_dir}/${pascal_slug}Test.lean" "${tmp_dir}/ExerciseTest.lean"
sed -i "s/import ${pascal_slug}/import Solution/g" "${tmp_dir}/ExerciseTest.lean"

cp -r "/opt/test-runner/." "${tmp_dir}"

cd "${tmp_dir}"

# Run the tests for the provided implementation file and redirect stdout and
# stderr to capture it
test_output=$(lake test 2>&1)
exit_code=$?

# Clean up temp directory
rm -rf "${tmp_dir}"

# Write the results.json file based on the exit code of the command that was
# just executed that tested the implementation file
if [ ${exit_code} -eq 0 ]; then
    jq -n '{version: 1, status: "pass"}' > ${results_file}
else
    # Check if this is a compilation/syntax error vs test failure
    if echo "${test_output}" | grep -q "error:"; then
        jq -n --arg output "${test_output}" '{version: 1, status: "error", message: $output}' > ${results_file}
    else
        jq -n --arg output "${test_output}" '{version: 1, status: "fail", message: $output}' > ${results_file}
    fi
fi

echo "${slug}: done"
