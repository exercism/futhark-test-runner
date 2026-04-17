#!/usr/bin/env sh

# Synopsis:
# Run the test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: path to solution folder
# $3: path to output directory

# Output:
# Writes a v2 results.json to the output directory, per
# https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md

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

# Symlink in the external packages
ln -sfn "/opt/test-runner/lib" "${solution_dir}/lib"

echo "${slug}: testing..."

test_output=$(futhark test "${solution_dir}/test.fut" 2>&1)
exit_code=$?

# Strip absolute paths from output so results are portable
test_output=$(printf '%s' "${test_output}" | sed "s#${solution_dir}/\{0,1\}##g")

# ---------- Extract test names and inputs from test.fut ----------
# Each test block: description comment, "-- ==", optional "-- entry:",
# "-- input { ... }" or "-- output { ... }" or "-- error: ...".
test_info_json=$(jq -Rs '
    def parse_entry: capture("^-- entry:\\s*(?<e>\\S+)") | .e;
    def parse_input: capture("^-- input\\s+(?<i>.*)") | .i;

    split("\n") |
    reduce .[] as $line (
        {state: "idle", comment: "", entry: "main", input: "", tests: []};
        if .state == "idle" then
            if ($line | startswith("-- ==")) then
                .state = "header"
            elif ($line | startswith("-- ")) then
                .comment = ($line | ltrimstr("-- "))
            else . end
        elif .state == "header" then
            if ($line | startswith("-- entry:")) then
                .entry = ($line | parse_entry)
            elif ($line | startswith("-- input")) then
                .input = ($line | parse_input)
                | .state = "body"
            elif ($line | startswith("-- output")) then
                .state = "body"
            elif ($line | startswith("-- error:")) then
                .state = "body"
            else . end
        elif .state == "body" then
            if ($line | test("^\\s*$")) then
                .tests += [{name: .comment, entry: .entry, input: .input}]
                | .comment = "" | .entry = "main" | .input = "" | .state = "idle"
            elif ($line | startswith("--")) then
                .
            else
                .tests += [{name: .comment, entry: .entry, input: .input}]
                | .comment = "" | .entry = "main" | .input = "" | .state = "idle"
            end
        else . end
    ) | if .state == "body" then
            .tests += [{name: .comment, entry: .entry, input: .input}]
        else . end
    | .tests
' "${solution_dir}/test.fut")

# ---------- Handle results based on exit code ----------
if [ ${exit_code} -eq 0 ]; then
    # All tests passed
    jq -n --argjson tests "${test_info_json}" '
        {version: 2, status: "pass", tests: [
            $tests[] | {name: .name, status: "pass"}
        ]}
    ' > "${results_file}"
elif printf '%s' "${test_output}" | grep -q "^Error at"; then
    # Compilation error — no per-test results
    jq -n --arg message "${test_output}" \
        '{version: 2, status: "error", message: $message}' > "${results_file}"
else
    # Test failures — parse output to identify which tests failed.
    # futhark test only prints failing tests:
    #   Entry point: main; dataset: #0 ("2100i32"):
    #   test.fut.main.0.actual and test.fut.main.0.expected do not match:
    #   Value #0: expected False, got True
    # Match failures to test blocks by entry point and input values.
    tests_json=$(jq -n \
        --argjson info "${test_info_json}" \
        --arg output "${test_output}" '

        def entry_point: capture("Entry point: (?<e>[^;]+)") | .e;
        def dataset_label: capture("\\(\"(?<l>[^\"]+)\"\\)") | .l // "";

        def parse_failures:
            split("\n") |
            reduce .[] as $line (
                {current: null, failures: []};
                if (($line | contains("Entry point:")) and ($line | contains("dataset:"))) then
                    (if .current then .failures += [.current] else . end)
                    | .current = {
                        entry: ($line | entry_point),
                        label: ($line | dataset_label),
                        message: ""
                    }
                elif .current then
                    .current.message += (
                        if .current.message != "" then "\n" + $line else $line end
                    )
                else . end
            ) | if .current then .failures += [.current] else . end
            | .failures
            | map(.message |= sub("\n+$"; ""));

        def strip_braces: ltrimstr("{") | rtrimstr("}");

        # "{ 2100 }" -> ["2100"];  "{ [30, 50] }" -> ["[30,", "50]"]
        def input_values:
            strip_braces | split(" ") | map(select(length > 0));

        def match_failure(failures):
            . as $test |
            if ($test.input | length) == 0 then null
            else
                ($test.input | input_values) as $tokens |
                [failures[] | select(
                    .entry == $test.entry and
                    (.label as $lbl | $tokens | all(inside($lbl)))
                )] | first // null
            end;

        ($output | parse_failures) as $failures |
        [
            $info[] |
            (match_failure($failures)) as $fail |
            if $fail then
                {name: .name, status: "fail", message: $fail.message}
            else
                {name: .name, status: "pass"}
            end
        ]
    ')

    overall=$(printf '%s' "${tests_json}" | jq -r '
        if any(.[]; .status == "fail") then "fail" else "pass" end
    ')

    jq -n --arg status "${overall}" --argjson tests "${tests_json}" \
        '{version: 2, status: $status, tests: $tests}' > "${results_file}"
fi

echo "${slug}: done"
