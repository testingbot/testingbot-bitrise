#!/usr/bin/env bash
#
# Offline tests for the TestingBot Bitrise Steps.
#
# Runs each step.sh against tests/mock_api.py rather than the real service, so
# the whole suite works without credentials and without spending device minutes.
# The live end-to-end checks live in each Step's bitrise.yml `e2e` workflow.
#
#   tests/run.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
MOCK_PID=""

pass_count=0
fail_count=0

# shellcheck disable=SC2329  # invoked via the EXIT trap
cleanup() {
  [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- assertions --------------------------------------------------------------

ok() {
  pass_count=$((pass_count + 1))
  printf '  \033[32mok\033[0m   %s\n' "$1"
}

nope() {
  fail_count=$((fail_count + 1))
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  [ -n "${2:-}" ] && printf '       %s\n' "$2"
}

assert_contains() {
  # assert_contains <description> <haystack> <needle>
  case "$2" in
  *"$3"*) ok "$1" ;;
  *) nope "$1" "expected to find: $3" ;;
  esac
}

assert_not_contains() {
  case "$2" in
  *"$3"*) nope "$1" "did not expect to find: $3" ;;
  *) ok "$1" ;;
  esac
}

assert_status() {
  # assert_status <description> <actual> <expected>
  if [ "$2" = "$3" ]; then
    ok "$1"
  else
    nope "$1" "exit status was $2, expected $3"
  fi
}

# --- harness -----------------------------------------------------------------

start_mock() {
  python3 "${REPO_ROOT}/tests/mock_api.py" >"${WORK}/port" 2>"${WORK}/mock.log" &
  MOCK_PID=$!
  # Detach so killing it at exit doesn't print a job-control notice.
  disown "$MOCK_PID" 2>/dev/null || true
  local tries=0
  while [ ! -s "${WORK}/port" ]; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
      echo "mock API failed to start:" >&2
      cat "${WORK}/mock.log" >&2
      exit 1
    fi
    sleep 0.1
  done
  MOCK_PORT="$(cat "${WORK}/port")"
  export TB_API_BASE="http://127.0.0.1:${MOCK_PORT}/v1"
}

# run_step <step-id> -- runs step.sh in a subshell with the current environment,
# capturing combined output into $OUTPUT and the exit status into $STATUS.
run_step() {
  set +e
  OUTPUT="$(bash "${REPO_ROOT}/steps/$1/step.sh" 2>&1)"
  STATUS=$?
  set -e
  set +u
}

# reset_env -- clear every input between test cases so they can't leak.
reset_env() {
  unset testingbot_key testingbot_secret app_path app_url app_key
  unset wait_for_processing processing_timeout
  unset BITRISE_APK_PATH BITRISE_AAB_PATH BITRISE_IPA_PATH BITRISE_APP_DIR_PATH
  export testingbot_key="test-key"
  export testingbot_secret="test-secret"
  export wait_for_processing="true"
  export processing_timeout="300"
}

# Poll every second rather than the production 3, so the waiting tests below
# cost a second or two instead of ten.
export TB_POLL_INTERVAL=1

# --- stubs -------------------------------------------------------------------
#
# tests/stubs/ shadows envman, npx, node and java so the suite behaves the same
# whether or not the Bitrise CLI and a JDK are installed on the machine. Without
# the envman stub these tests silently depend on envman being absent.

export PATH="${REPO_ROOT}/tests/stubs:${PATH}"
export STUB_ENVMAN_FILE="${WORK}/envman"

# --- fixtures ----------------------------------------------------------------

start_mock
FIXTURE_APK="${WORK}/sample-debug.apk"
head -c 2048 /dev/urandom >"$FIXTURE_APK"

echo
echo "testingbot-upload-app"

# 1. Happy path: explicit app path.
reset_env
export app_path="$FIXTURE_APK"
run_step testingbot-upload-app
assert_status "uploads an app and exits 0" "$STATUS" 0
assert_contains "exports the tb:// identifier" "$OUTPUT" "TESTINGBOT_APP_URL=tb://"
assert_contains "reads the app back after uploading" "$OUTPUT" "Reading the stored app"
# The upload POST returns only app_url, so id/version/platform must come from
# the follow-up GET -- exactly what broke against the live API first time.
assert_contains "exports the id from the metadata call" "$OUTPUT" "TESTINGBOT_APP_ID=12345"
assert_contains "exports the version" "$OUTPUT" "TESTINGBOT_APP_VERSION=1.4.2"
assert_contains "exports the detected platform" "$OUTPUT" "TESTINGBOT_APP_TYPE=ANDROID"
assert_contains "exports the metadata state" "$OUTPUT" "TESTINGBOT_APP_STATE=DONE"
assert_contains "exports a download URL" "$OUTPUT" "TESTINGBOT_APP_DOWNLOAD_URL=https://"

# 2. Auto-detection from the preceding build Step.
reset_env
export BITRISE_APK_PATH="$FIXTURE_APK"
run_step testingbot-upload-app
assert_status "auto-detects \$BITRISE_APK_PATH" "$STATUS" 0
assert_contains "says it auto-detected the artifact" "$OUTPUT" "using the artifact from the preceding build Step"

# 3. Auto-detection falls through to the IPA when there is no APK.
reset_env
export BITRISE_APK_PATH="${WORK}/does-not-exist.apk"
export BITRISE_IPA_PATH="$FIXTURE_APK"
run_step testingbot-upload-app
assert_status "falls through to \$BITRISE_IPA_PATH" "$STATUS" 0

# 4. Stable app identifier.
reset_env
export app_path="$FIXTURE_APK"
export app_key="my-stable-app"
run_step testingbot-upload-app
assert_status "uploads under a stable app_key" "$STATUS" 0
assert_contains "keeps the requested identifier" "$OUTPUT" "TESTINGBOT_APP_URL=tb://my-stable-app"

# 5. Remote URL upload.
reset_env
export app_url="https://example.com/app.apk"
run_step testingbot-upload-app
assert_status "uploads from a public URL" "$STATUS" 0
assert_contains "reports the source URL" "$OUTPUT" "https://example.com/app.apk"

# 6. Metadata extraction runs asynchronously: the Step must wait for state DONE
#    rather than reporting the null version it sees on the first GET.
reset_env
export app_path="$FIXTURE_APK"
export app_key="slowmeta-app"
run_step testingbot-upload-app
assert_status "waits out PROCESSING and exits 0" "$STATUS" 0
assert_contains "says it is waiting" "$OUTPUT" "waiting for state DONE"
assert_contains "reports how long it waited" "$OUTPUT" "Metadata ready after"
assert_contains "ends up DONE" "$OUTPUT" "TESTINGBOT_APP_STATE=DONE"
# The whole point of waiting: the version is absent on the early GETs.
assert_contains "exports the version the wait uncovered" "$OUTPUT" "TESTINGBOT_APP_VERSION=1.4.2"

# 7. Waiting is optional. Without it the Step returns immediately with whatever
#    the API has so far, and says so through TESTINGBOT_APP_STATE.
reset_env
export app_path="$FIXTURE_APK"
export app_key="slowmeta-nowait"
export wait_for_processing="false"
run_step testingbot-upload-app
assert_status "skips the wait when asked" "$STATUS" 0
assert_not_contains "does not wait" "$OUTPUT" "waiting for state DONE"
assert_contains "reports the unfinished state" "$OUTPUT" "TESTINGBOT_APP_STATE=PROCESSING"
assert_contains "still exports the identifier" "$OUTPUT" "TESTINGBOT_APP_URL=tb://"

# 8. Metadata that never finishes must not fail an upload that succeeded -- the
#    binary is stored and testable either way.
reset_env
export app_path="$FIXTURE_APK"
export app_key="stuckmeta-app"
export processing_timeout="2"
run_step testingbot-upload-app
assert_status "a metadata timeout does not fail the Step" "$STATUS" 0
assert_contains "warns that it gave up" "$OUTPUT" "Still PROCESSING after 2s"
assert_contains "reports the state it gave up in" "$OUTPUT" "TESTINGBOT_APP_STATE=PROCESSING"
assert_contains "still exports the identifier" "$OUTPUT" "TESTINGBOT_APP_URL=tb://stuckmeta-app"

# 9. A non-numeric timeout falls back to the default instead of erroring out.
reset_env
export app_path="$FIXTURE_APK"
export processing_timeout="not-a-number"
run_step testingbot-upload-app
assert_status "survives a bad processing_timeout" "$STATUS" 0
assert_contains "warns about the bad value" "$OUTPUT" "is not a number"

# 10. No app anywhere -> named error, not a curl error.
reset_env
run_step testingbot-upload-app
assert_status "fails when there is no app to upload" "$STATUS" 1
assert_contains "explains which Step produces the artifact" "$OUTPUT" "Could not find the app binary"
assert_contains "names the build Step to add" "$OUTPUT" "BITRISE_APK_PATH"

# 11. Explicit path that does not exist.
reset_env
export app_path="${WORK}/nope.apk"
run_step testingbot-upload-app
assert_status "fails when the given path is missing" "$STATUS" 1
assert_contains "reports the path it looked for" "$OUTPUT" "nope.apk"

# 12. Bad credentials -> the named auth error, not raw JSON.
reset_env
export app_path="$FIXTURE_APK"
export testingbot_secret="wrong"
run_step testingbot-upload-app
assert_status "fails on bad credentials" "$STATUS" 1
assert_contains "maps HTTP 401 to a readable message" "$OUTPUT" "rejected the credentials"
assert_contains "points at the member area" "$OUTPUT" "testingbot.com/members/user/api"

# 13. Read-only account -> the named 403 error.
reset_env
export app_url="https://example.com/readonly.apk"
run_step testingbot-upload-app
assert_status "fails on a read-only account" "$STATUS" 1
assert_contains "maps HTTP 403 to a readable message" "$OUTPUT" "read-only"

# 14. Empty credentials are caught before any network call.
reset_env
export testingbot_key=""
export app_path="$FIXTURE_APK"
run_step testingbot-upload-app
assert_status "fails when the key input is empty" "$STATUS" 1
assert_contains "names the empty input" "$OUTPUT" "testingbot_key"

# 15. An unreachable API is a real failure -- the upload never happened.
reset_env
export app_path="$FIXTURE_APK"
export TB_API_BASE="http://127.0.0.1:1/v1"
run_step testingbot-upload-app
export TB_API_BASE="http://127.0.0.1:${MOCK_PORT}/v1"
assert_status "an unreachable API still fails the upload itself" "$STATUS" 1

# --- testingbot-espresso -----------------------------------------------------
#
# These run against tests/stubs/npx rather than the real TestingBot CLI, so we
# can assert on the exact argument vector the Step builds and drive the CLI's
# exit code to check how the Step turns a test failure into a build result.

export STUB_ARGV_FILE="${WORK}/argv"

reset_espresso_env() {
  unset testingbot_key testingbot_secret device app_path test_app_path
  unset platform_version real_device tablet_only phone_only locale language timezone
  unset build_name test_name test_runner filter_size fail_on_test_failure run_async
  unset filter_class filter_not_class filter_package filter_not_package
  unset filter_annotation filter_not_annotation
  unset throttle_network geo_country_code tunnel tunnel_identifier
  unset export_to_test_reports report_output_dir cli_version additional_args quiet
  unset BITRISE_APK_PATH BITRISE_TEST_APK_PATH BITRISE_TEST_RESULT_DIR
  unset BITRISE_GIT_COMMIT BITRISE_PULL_REQUEST GIT_REPOSITORY_URL BITRISE_APP_TITLE
  unset STUB_NODE_VERSION
  export STUB_NPX_EXIT=0
  export testingbot_key="test-key"
  export testingbot_secret="test-secret"
  export device="Pixel 8"
  export cli_version="1.1.1"
  export test_name="Espresso"
  export fail_on_test_failure="true"
  export export_to_test_reports="true"
  : >"$STUB_ARGV_FILE"
}

# argv_has <flag> <value> -- was `--flag value` passed as two adjacent argv entries?
argv_has() {
  grep -A1 -x -F -- "$1" "$STUB_ARGV_FILE" 2>/dev/null | grep -q -x -F -- "$2"
}

argv_has_flag() {
  grep -q -x -F -- "$1" "$STUB_ARGV_FILE" 2>/dev/null
}

assert_argv() {
  # assert_argv <description> <flag> <value>
  if argv_has "$2" "$3"; then ok "$1"; else nope "$1" "expected argv to contain: $2 $3"; fi
}

assert_argv_flag() {
  if argv_has_flag "$2"; then ok "$1"; else nope "$1" "expected argv to contain: $2"; fi
}

assert_no_argv_flag() {
  if argv_has_flag "$2"; then nope "$1" "did not expect argv to contain: $2"; else ok "$1"; fi
}

echo
echo "testingbot-espresso"

APP_APK="${WORK}/app-debug.apk"
TEST_APK="${WORK}/app-debug-androidTest.apk"
head -c 512 /dev/urandom >"$APP_APK"
head -c 512 /dev/urandom >"$TEST_APK"

# 1. Happy path.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export BITRISE_TEST_RESULT_DIR="${WORK}/results1"
mkdir -p "$BITRISE_TEST_RESULT_DIR"
run_step testingbot-espresso
assert_status "passes when the suite passes" "$STATUS" 0
assert_contains "reports success" "$OUTPUT" "All tests passed."
assert_contains "exports a passed status" "$OUTPUT" "TESTINGBOT_TEST_STATUS=passed"
assert_argv "passes the device through" --device "Pixel 8"
assert_argv "asks for a JUnit report" --report junit
assert_argv "names the test" --name "Espresso"

# The Test Reports layout is what makes results show up on the Bitrise tab.
if [ -f "${BITRISE_TEST_RESULT_DIR}/Espresso/test-info.json" ]; then
  ok "writes test-info.json for Test Reports"
else
  nope "writes test-info.json for Test Reports"
fi
if [ -f "${BITRISE_TEST_RESULT_DIR}/Espresso/junit.xml" ]; then
  ok "copies the JUnit report into the Test Reports directory"
else
  nope "copies the JUnit report into the Test Reports directory"
fi
assert_contains "test-info.json names the test" "$(cat "${BITRISE_TEST_RESULT_DIR}/Espresso/test-info.json" 2>/dev/null)" '"test-name":"Espresso"'

# 2. A failing suite fails the build -- the headline behaviour.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export STUB_NPX_EXIT=1
run_step testingbot-espresso
assert_status "fails the build when a test fails" "$STATUS" 1
assert_contains "says the tests failed" "$OUTPUT" "Tests failed."
assert_contains "exports a failed status" "$OUTPUT" "TESTINGBOT_TEST_STATUS=failed"
assert_contains "mentions the opt-out" "$OUTPUT" "fail_on_test_failure"

# 3. ...unless the user opted out.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export STUB_NPX_EXIT=1
export fail_on_test_failure="false"
run_step testingbot-espresso
assert_status "keeps the build green when fail_on_test_failure is off" "$STATUS" 0
assert_contains "still exports the failed status" "$OUTPUT" "TESTINGBOT_TEST_STATUS=failed"

# 4. Auto-detection from the preceding Android Build Step.
reset_espresso_env
export BITRISE_APK_PATH="$APP_APK"
export BITRISE_TEST_APK_PATH="$TEST_APK"
run_step testingbot-espresso
assert_status "auto-detects both APKs" "$STATUS" 0
assert_contains "uses the detected app APK" "$OUTPUT" "app-debug.apk"

# 5. Missing test APK is a named error.
reset_espresso_env
export app_path="$APP_APK"
run_step testingbot-espresso
assert_status "fails without a test APK" "$STATUS" 1
assert_contains "explains how to produce the test APK" "$OUTPUT" "BITRISE_TEST_APK_PATH"

# 6. Filters map onto the CLI's flags.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export filter_class="com.example.LoginTest"
export filter_not_package="com.example.slow"
export filter_annotation="com.example.SmokeTest"
export filter_size="small,medium"
run_step testingbot-espresso
assert_status "runs with filters" "$STATUS" 0
assert_argv "maps filter_class" --class "com.example.LoginTest"
assert_argv "maps filter_not_package" --not-package "com.example.slow"
assert_argv "maps filter_annotation" --annotation "com.example.SmokeTest"
assert_argv "maps filter_size" --size "small,medium"

# 7. Empty inputs must not produce empty flags.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
run_step testingbot-espresso
assert_no_argv_flag "omits --platform-version when unset" --platform-version
assert_no_argv_flag "omits --class when unset" --class
assert_no_argv_flag "omits --real-device when false" --real-device

# 8. Booleans become bare switches.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export real_device="true" tablet_only="true"
run_step testingbot-espresso
assert_argv_flag "passes --real-device when enabled" --real-device
assert_argv_flag "passes --tablet-only when enabled" --tablet-only

# 9. Async runs skip reporting and never fail the build.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export run_async="true"
export STUB_NPX_EXIT=1
run_step testingbot-espresso
assert_status "an async run does not fail the build" "$STATUS" 0
assert_argv_flag "passes --async" --async
assert_no_argv_flag "does not ask for a report when async" --report

# 10. CI metadata is forwarded, which drives TestingBot's PR checks.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export BITRISE_GIT_COMMIT="abc123"
export BITRISE_PULL_REQUEST="42"
export GIT_REPOSITORY_URL="git@github.com:testingbot/example-app.git"
run_step testingbot-espresso
assert_argv "forwards the commit SHA" --commit-sha "abc123"
assert_argv "forwards the pull request id" --pull-request-id "42"
assert_argv "derives the repo owner" --repo-owner "testingbot"
assert_argv "derives the repo name" --repo-name "example-app"

# 10b. Flag names the real CLI actually accepts.
#      Verified against `npx @testingbot/cli@1.1.1 espresso --help`: the CLI
#      calls this --geo-country-code, not the --geo-location its README shows.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export geo_country_code="DE"
export BITRISE_APP_TITLE="Example App"
export BITRISE_BUILD_NUMBER="9"
run_step testingbot-espresso
assert_argv "uses --geo-country-code, not --geo-location" --geo-country-code "DE"
assert_no_argv_flag "never emits --geo-location" --geo-location
assert_argv_flag "espresso accepts --build" --build

# 11. The additional_args escape hatch.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export additional_args="--some-new-flag value"
run_step testingbot-espresso
assert_argv "passes additional_args through" --some-new-flag "value"

# 12. The default build name groups sessions per Bitrise build.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export BITRISE_APP_TITLE="Example App"
export BITRISE_BUILD_NUMBER="77"
run_step testingbot-espresso
assert_argv "defaults the build name to the Bitrise build" --build "Example App #77"

# 13. Node version gate.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export STUB_NODE_VERSION="v18.19.0"
run_step testingbot-espresso
assert_status "fails on Node older than 20" "$STATUS" 1
assert_contains "names the Node requirement" "$OUTPUT" "Node.js 20"

# 14. Missing device input.
reset_espresso_env
export app_path="$APP_APK" test_app_path="$TEST_APK"
export device=""
run_step testingbot-espresso
assert_status "fails without a device" "$STATUS" 1
assert_contains "names the device input" "$OUTPUT" "device"

# --- testingbot-maestro ------------------------------------------------------

reset_maestro_env() {
  unset testingbot_key testingbot_secret device flows app_path
  unset platform platform_version real_device orientation locale timezone
  unset groups test_name include_tags exclude_tags flow_env
  unset fail_on_test_failure shard_split retry run_async
  unset throttle_network geo_country_code tunnel tunnel_identifier
  unset export_to_test_reports download_artifacts report_output_dir
  unset maestro_version maestro_config cli_version additional_args quiet
  unset BITRISE_APK_PATH BITRISE_AAB_PATH BITRISE_IPA_PATH BITRISE_APP_DIR_PATH
  unset BITRISE_TEST_RESULT_DIR BITRISE_DEPLOY_DIR
  unset BITRISE_GIT_COMMIT BITRISE_PULL_REQUEST GIT_REPOSITORY_URL BITRISE_APP_TITLE
  unset STUB_NODE_VERSION
  export STUB_NPX_EXIT=0
  export testingbot_key="test-key"
  export testingbot_secret="test-secret"
  export device="Pixel 9"
  export cli_version="1.1.1"
  export test_name="Maestro"
  export fail_on_test_failure="true"
  export export_to_test_reports="true"
  export download_artifacts="none"
  export shard_split="0"
  export retry="0"
  : >"$STUB_ARGV_FILE"
}

argv_has_positional() {
  grep -q -x -F -- "$1" "$STUB_ARGV_FILE" 2>/dev/null
}

echo
echo "testingbot-maestro"

FLOW_DIR="${WORK}/.maestro"
mkdir -p "${FLOW_DIR}/smoke" "${FLOW_DIR}/checkout"
: >"${FLOW_DIR}/smoke/login.yaml"
: >"${FLOW_DIR}/checkout/pay.yaml"

# 1. Happy path.
reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
export BITRISE_TEST_RESULT_DIR="${WORK}/results-maestro"
mkdir -p "$BITRISE_TEST_RESULT_DIR"
run_step testingbot-maestro
assert_status "passes when the flows pass" "$STATUS" 0
assert_contains "reports success" "$OUTPUT" "All flows passed."
assert_argv "passes the device through" --device "Pixel 9"
if argv_has_positional "$FLOW_DIR"; then ok "passes the flow directory positionally"; else nope "passes the flow directory positionally"; fi
if [ -f "${BITRISE_TEST_RESULT_DIR}/Maestro/test-info.json" ]; then
  ok "exports the report to Test Reports"
else
  nope "exports the report to Test Reports"
fi

# 2. Several flow paths, one per line.
reset_maestro_env
export app_path="$APP_APK"
flows="${FLOW_DIR}/smoke
${FLOW_DIR}/checkout"
export flows
run_step testingbot-maestro
assert_status "accepts a newline-separated flow list" "$STATUS" 0
if argv_has_positional "${FLOW_DIR}/smoke" && argv_has_positional "${FLOW_DIR}/checkout"; then
  ok "passes every flow path"
else
  nope "passes every flow path"
fi

# 3. Pipe-separated works too, per the Bitrise list convention.
reset_maestro_env
export app_path="$APP_APK"
export flows="${FLOW_DIR}/smoke|${FLOW_DIR}/checkout"
run_step testingbot-maestro
if argv_has_positional "${FLOW_DIR}/smoke" && argv_has_positional "${FLOW_DIR}/checkout"; then
  ok "accepts a pipe-separated flow list"
else
  nope "accepts a pipe-separated flow list"
fi

# 4. Flow environment variables each become their own -e flag.
reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
flow_env="API_URL=https://staging.example.com
USER=demo"
export flow_env
run_step testingbot-maestro
assert_argv "passes the first flow env var" -e "API_URL=https://staging.example.com"
assert_argv "passes the second flow env var" -e "USER=demo"

# 5. Sharding and retry only appear when non-zero.
reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
run_step testingbot-maestro
assert_no_argv_flag "omits --shard-split when 0" --shard-split
assert_no_argv_flag "omits --retry when 0" --retry

reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
export shard_split="3" retry="2"
run_step testingbot-maestro
assert_argv "passes --shard-split when set" --shard-split "3"
assert_argv "passes --retry when set" --retry "2"

# 6. Artifacts land in the deploy dir so Deploy to Bitrise.io picks them up.
reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
export download_artifacts="failed"
export BITRISE_DEPLOY_DIR="${WORK}/deploy"
mkdir -p "$BITRISE_DEPLOY_DIR"
run_step testingbot-maestro
assert_argv "requests failed-only artifacts" --download-artifacts "failed"
assert_argv "writes artifacts to the deploy dir" --artifacts-output-dir "$BITRISE_DEPLOY_DIR"

reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
run_step testingbot-maestro
assert_no_argv_flag "omits artifact download by default" --download-artifacts

# 6b. Maestro's CLI has no --build; sending it would abort every run.
#     Verified against `npx @testingbot/cli@1.1.1 maestro --help`.
reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
export groups="nightly,critical"
export geo_country_code="DE"
export BITRISE_APP_TITLE="Example App"
export BITRISE_BUILD_NUMBER="9"
run_step testingbot-maestro
assert_no_argv_flag "never sends --build to maestro" --build
assert_argv "uses --groups instead" --groups "nightly,critical"
assert_argv "uses --geo-country-code" --geo-country-code "DE"

# 7. A failing flow fails the build.
reset_maestro_env
export app_path="$APP_APK" flows="$FLOW_DIR"
export STUB_NPX_EXIT=1
run_step testingbot-maestro
assert_status "fails the build when a flow fails" "$STATUS" 1
assert_contains "says the flows failed" "$OUTPUT" "Flows failed."

# 8. Missing flows input.
reset_maestro_env
export app_path="$APP_APK"
export flows=""
run_step testingbot-maestro
assert_status "fails without flows" "$STATUS" 1
assert_contains "names the flows input" "$OUTPUT" "flows"

# --- testingbot-xcuitest -----------------------------------------------------

reset_xcuitest_env() {
  unset testingbot_key testingbot_secret device app_path test_app_path
  unset platform_version real_device tablet_only phone_only orientation
  unset locale language timezone build_name test_name geo_country_code
  unset fail_on_test_failure run_async throttle_network geo_country_code
  unset tunnel tunnel_identifier export_to_test_reports report_output_dir
  unset cli_version additional_args quiet
  unset BITRISE_IPA_PATH BITRISE_APP_DIR_PATH BITRISE_TEST_BUNDLE_PATH
  unset BITRISE_TEST_RESULT_DIR
  unset BITRISE_GIT_COMMIT BITRISE_PULL_REQUEST GIT_REPOSITORY_URL BITRISE_APP_TITLE
  unset STUB_NODE_VERSION
  export STUB_NPX_EXIT=0
  export testingbot_key="test-key"
  export testingbot_secret="test-secret"
  export device="iPhone 16"
  export cli_version="1.1.1"
  export test_name="XCUITest"
  export fail_on_test_failure="true"
  export export_to_test_reports="true"
  : >"$STUB_ARGV_FILE"
}

echo
echo "testingbot-xcuitest"

APP_IPA="${WORK}/Example.ipa"
head -c 512 /dev/urandom >"$APP_IPA"

# A test bundle shaped the way `Xcode Build for testing` exports one.
BUNDLE_DIR="${WORK}/test-bundle"
RUNNER_APP="${BUNDLE_DIR}/Debug-iphoneos/ExampleUITests-Runner.app"
mkdir -p "$RUNNER_APP"
echo "binary" >"${RUNNER_APP}/ExampleUITests-Runner"

# 1. The runner app is found inside the bundle directory and zipped.
reset_xcuitest_env
export app_path="$APP_IPA" test_app_path="$BUNDLE_DIR"
run_step testingbot-xcuitest
assert_status "handles an Xcode test bundle directory" "$STATUS" 0
assert_contains "reports the runner it found" "$OUTPUT" "ExampleUITests-Runner.app"
assert_contains "zips the runner" "$OUTPUT" "Zipped to"
zipped_arg="$(grep -m1 -E '\.zip$' "$STUB_ARGV_FILE" || true)"
if [ -n "$zipped_arg" ] && [ -f "$zipped_arg" ]; then
  ok "passes a real zip to the CLI"
  # No `grep -q`: it would close the pipe early, and pipefail turns the
  # resulting SIGPIPE on unzip into a spurious failure.
  if unzip -l "$zipped_arg" 2>/dev/null | grep -F "ExampleUITests-Runner.app" >/dev/null; then
    ok "the zip contains the runner app"
  else
    nope "the zip contains the runner app"
  fi
else
  nope "passes a real zip to the CLI" "argv had no existing .zip entry"
fi

# 2. A path straight to the runner app also works.
reset_xcuitest_env
export app_path="$APP_IPA" test_app_path="$RUNNER_APP"
run_step testingbot-xcuitest
assert_status "accepts a *-Runner.app path" "$STATUS" 0

# 3. An existing zip is passed through untouched.
reset_xcuitest_env
PREZIPPED="${WORK}/prezipped-tests.zip"
: >"$PREZIPPED"
export app_path="$APP_IPA" test_app_path="$PREZIPPED"
run_step testingbot-xcuitest
assert_status "accepts a prebuilt zip" "$STATUS" 0
assert_not_contains "does not re-zip a zip" "$OUTPUT" "Packaging the XCUITest runner"

# 4. A bundle directory with no runner is a named error.
reset_xcuitest_env
EMPTY_BUNDLE="${WORK}/empty-bundle"
mkdir -p "$EMPTY_BUNDLE"
export app_path="$APP_IPA" test_app_path="$EMPTY_BUNDLE"
run_step testingbot-xcuitest
assert_status "fails when no runner app exists" "$STATUS" 1
assert_contains "explains the device-destination requirement" "$OUTPUT" "Runner.app"

# 5. Auto-detection from the Xcode Steps.
reset_xcuitest_env
export BITRISE_IPA_PATH="$APP_IPA"
export BITRISE_TEST_BUNDLE_PATH="$BUNDLE_DIR"
run_step testingbot-xcuitest
assert_status "auto-detects the IPA and test bundle" "$STATUS" 0

# 5b. A simulator build is a `.app` DIRECTORY, which is what
#     $BITRISE_APP_DIR_PATH holds and what `real_device: false` implies. The
#     uploader only accepts zip-format archives, so the Step has to zip it --
#     passing the directory through fails against the real CLI.
reset_xcuitest_env
SIM_APP_DIR="${WORK}/Example.app"
mkdir -p "$SIM_APP_DIR"
: >"${SIM_APP_DIR}/Example"
export BITRISE_APP_DIR_PATH="$SIM_APP_DIR"
export BITRISE_TEST_BUNDLE_PATH="$BUNDLE_DIR"
run_step testingbot-xcuitest
assert_status "accepts a .app directory" "$STATUS" 0
assert_contains "zips the app bundle" "$OUTPUT" "Packaging the app bundle"
# The app is the first positional after the subcommand; it must be the zip.
assert_contains "hands the CLI a zip, not a directory" \
  "$(awk '/^xcuitest$/ {getline; print; exit}' "$STUB_ARGV_FILE")" "Example.app.zip"

# 5c. An .ipa is already an archive and must not be touched.
reset_xcuitest_env
export app_path="$APP_IPA" test_app_path="$BUNDLE_DIR"
run_step testingbot-xcuitest
assert_not_contains "does not re-zip an .ipa" "$OUTPUT" "Packaging the app bundle"

# 6. A failing suite fails the build.
reset_xcuitest_env
export app_path="$APP_IPA" test_app_path="$BUNDLE_DIR"
export STUB_NPX_EXIT=1
run_step testingbot-xcuitest
assert_status "fails the build when a test fails" "$STATUS" 1

# 6b. xcuitest does accept --build, and uses --geo-country-code.
reset_xcuitest_env
export app_path="$APP_IPA" test_app_path="$BUNDLE_DIR"
export geo_country_code="US"
run_step testingbot-xcuitest
assert_argv_flag "xcuitest accepts --build" --build
assert_argv "uses --geo-country-code" --geo-country-code "US"
assert_no_argv_flag "never emits --geo-location" --geo-location

# 7. iOS-specific flags.
reset_xcuitest_env
export app_path="$APP_IPA" test_app_path="$BUNDLE_DIR"
export tablet_only="true" orientation="LANDSCAPE" platform_version="17.2"
run_step testingbot-xcuitest
assert_argv_flag "passes --tablet-only" --tablet-only
assert_argv "passes --orientation" --orientation "LANDSCAPE"
assert_argv "passes --platform-version" --platform-version "17.2"

# --- testingbot-tunnel / testingbot-tunnel-stop ------------------------------
#
# The tunnel archive is served from the mock's directory via a file:// URL and
# `java` is stubbed, so the download, checksum, readiness and shutdown paths all
# run for real without touching the network or needing a JDK.

echo
echo "testingbot-tunnel"

TUNNEL_ARCHIVE_DIR="${WORK}/tunnel-dist"
mkdir -p "${TUNNEL_ARCHIVE_DIR}/pkg"
# The real archive names the jar after the release -- testingbot-tunnel-4.8.jar
# -- even though the download URL is unversioned, so the name moves with every
# tunnel release. The fixture used to be `testingbot-tunnel.jar`, which is what
# let the Step ship a find(1) for a name that never actually exists.
echo "not really a jar" >"${TUNNEL_ARCHIVE_DIR}/pkg/testingbot-tunnel-4.8.jar"
(cd "${TUNNEL_ARCHIVE_DIR}/pkg" && zip -qry "${TUNNEL_ARCHIVE_DIR}/testingbot-tunnel.zip" "testingbot-tunnel-4.8.jar")
TUNNEL_ARCHIVE="${TUNNEL_ARCHIVE_DIR}/testingbot-tunnel.zip"
TUNNEL_SHA="$(shasum -a 256 "$TUNNEL_ARCHIVE" | awk '{print $1}')"

reset_tunnel_env() {
  unset testingbot_key testingbot_secret tunnel_identifier ready_timeout
  unset log_level additional_args download_url download_sha256
  unset tunnel_pid tunnel_log_path print_log shutdown_timeout
  unset STUB_JAVA_MODE STUB_JAVA_DELAY
  export testingbot_key="test-key"
  export testingbot_secret="test-secret"
  export tunnel_identifier="bitrise-test-$$"
  export ready_timeout="20"
  export log_level="info"
  export download_url="file://${TUNNEL_ARCHIVE}"
  # Each case gets its own work dir so a stale ready file can't mask a bug.
  TMPDIR="$(mktemp -d)"
  export TMPDIR
}

stop_tunnel_if_running() {
  if [ -n "${TESTINGBOT_TUNNEL_PID_VALUE:-}" ]; then
    kill -KILL "$TESTINGBOT_TUNNEL_PID_VALUE" 2>/dev/null || true
  fi
}

# The Step prints outputs rather than calling envman outside a build, so read
# the pid back out of its log.
pid_from_output() {
  printf '%s' "$OUTPUT" | sed -n 's/.*TESTINGBOT_TUNNEL_PID=\([0-9][0-9]*\).*/\1/p' | head -1
}

# 1. Happy path: downloads, unpacks, starts and waits for the ready file.
reset_tunnel_env
run_step testingbot-tunnel
assert_status "starts the tunnel" "$STATUS" 0
assert_contains "downloads the tunnel" "$OUTPUT" "Downloading the TestingBot Tunnel"
assert_contains "unpacks the version-suffixed jar" "$OUTPUT" "testingbot-tunnel-4.8.jar"
assert_contains "waits for readiness" "$OUTPUT" "Tunnel ready after"
assert_contains "exports the identifier" "$OUTPUT" "TESTINGBOT_TUNNEL_IDENTIFIER=bitrise-test-"
assert_contains "warns about the stop Step" "$OUTPUT" "TestingBot Tunnel Stop"
TESTINGBOT_TUNNEL_PID_VALUE="$(pid_from_output)"
if [ -n "$TESTINGBOT_TUNNEL_PID_VALUE" ] && kill -0 "$TESTINGBOT_TUNNEL_PID_VALUE" 2>/dev/null; then
  ok "leaves the tunnel running for later Steps"
else
  nope "leaves the tunnel running for later Steps"
fi

# 2. ...and the stop Step shuts it down.
TUNNEL_LOG="$(printf '%s' "$OUTPUT" | sed -n 's/.*TESTINGBOT_TUNNEL_LOG_PATH=\(.*\)$/\1/p' | head -1)"
export tunnel_pid="$TESTINGBOT_TUNNEL_PID_VALUE"
export tunnel_log_path="$TUNNEL_LOG"
export print_log="false"
export shutdown_timeout="10"
run_step testingbot-tunnel-stop
assert_status "stops the tunnel" "$STATUS" 0
assert_contains "reports the shutdown" "$OUTPUT" "Tunnel stopped."
if kill -0 "$TESTINGBOT_TUNNEL_PID_VALUE" 2>/dev/null; then
  nope "the tunnel process is gone"
else
  ok "the tunnel process is gone"
fi
TESTINGBOT_TUNNEL_PID_VALUE=""

# 3. Checksum verification.
reset_tunnel_env
export download_sha256="$TUNNEL_SHA"
run_step testingbot-tunnel
assert_status "accepts a matching checksum" "$STATUS" 0
assert_contains "says the checksum was verified" "$OUTPUT" "Checksum verified."
TESTINGBOT_TUNNEL_PID_VALUE="$(pid_from_output)"
stop_tunnel_if_running

reset_tunnel_env
export download_sha256="0000000000000000000000000000000000000000000000000000000000000000"
run_step testingbot-tunnel
assert_status "refuses a mismatched checksum" "$STATUS" 1
assert_contains "reports the mismatch" "$OUTPUT" "does not match the expected checksum"

reset_tunnel_env
run_step testingbot-tunnel
assert_contains "warns when no checksum is configured" "$OUTPUT" "integrity was not verified"
TESTINGBOT_TUNNEL_PID_VALUE="$(pid_from_output)"
stop_tunnel_if_running

# 4. A tunnel that dies on startup fails fast and shows its log.
reset_tunnel_env
export STUB_JAVA_MODE="crash"
run_step testingbot-tunnel
assert_status "fails when the tunnel exits at startup" "$STATUS" 1
assert_contains "notices the process died" "$OUTPUT" "exited before it became ready"
assert_contains "prints the tunnel log" "$OUTPUT" "could not authenticate"

# 5. A tunnel that never becomes ready times out rather than hanging the build.
reset_tunnel_env
export STUB_JAVA_MODE="hang"
export ready_timeout="4"
run_step testingbot-tunnel
assert_status "times out on a tunnel that never comes up" "$STATUS" 1
assert_contains "reports the timeout" "$OUTPUT" "did not become ready within"
assert_contains "suggests raising the timeout" "$OUTPUT" "ready_timeout"

# 6. A slow-but-fine tunnel is waited for.
reset_tunnel_env
export STUB_JAVA_DELAY="3"
run_step testingbot-tunnel
assert_status "waits for a slow tunnel" "$STATUS" 0
TESTINGBOT_TUNNEL_PID_VALUE="$(pid_from_output)"
stop_tunnel_if_running

# 7. A bad download URL is a clean failure.
reset_tunnel_env
export download_url="file://${WORK}/no-such-archive.zip"
run_step testingbot-tunnel
assert_status "fails on an unreachable download" "$STATUS" 1
assert_contains "names the URL it tried" "$OUTPUT" "no-such-archive.zip"

# 8. An archive with no jar in it fails with a named error rather than trying
#    to run `java -jar ""`.
reset_tunnel_env
NO_JAR_DIR="${WORK}/tunnel-nojar"
mkdir -p "${NO_JAR_DIR}/pkg"
echo "changelog" >"${NO_JAR_DIR}/pkg/CHANGELOG"
(cd "${NO_JAR_DIR}/pkg" && zip -qry "${NO_JAR_DIR}/testingbot-tunnel.zip" "CHANGELOG")
export download_url="file://${NO_JAR_DIR}/testingbot-tunnel.zip"
run_step testingbot-tunnel
assert_status "fails when the archive has no jar" "$STATUS" 1
assert_contains "says the jar is missing" "$OUTPUT" "did not contain a testingbot-tunnel jar"

# 9. Any future rename that keeps the prefix still resolves.
reset_tunnel_env
NEXT_DIR="${WORK}/tunnel-next"
mkdir -p "${NEXT_DIR}/pkg"
echo "not really a jar" >"${NEXT_DIR}/pkg/testingbot-tunnel-5.0.1.jar"
(cd "${NEXT_DIR}/pkg" && zip -qry "${NEXT_DIR}/testingbot-tunnel.zip" "testingbot-tunnel-5.0.1.jar")
export download_url="file://${NEXT_DIR}/testingbot-tunnel.zip"
run_step testingbot-tunnel
assert_status "handles a future tunnel version" "$STATUS" 0
assert_contains "finds the renamed jar" "$OUTPUT" "testingbot-tunnel-5.0.1.jar"
TESTINGBOT_TUNNEL_PID_VALUE="$(pid_from_output)"
stop_tunnel_if_running

echo
echo "testingbot-tunnel-stop"

# 8. Nothing to stop is not an error -- this Step must never fail a build.
reset_tunnel_env
export tunnel_pid=""
run_step testingbot-tunnel-stop
assert_status "succeeds when there is no tunnel to stop" "$STATUS" 0
assert_contains "explains what it expected" "$OUTPUT" "TESTINGBOT_TUNNEL_PID"

# 9. An already-dead tunnel is not an error either.
reset_tunnel_env
export tunnel_pid="999999"
export tunnel_log_path=""
run_step testingbot-tunnel-stop
assert_status "succeeds when the tunnel already exited" "$STATUS" 0
assert_contains "says it is already gone" "$OUTPUT" "not running any more"

# --- summary -----------------------------------------------------------------

echo
if [ "$fail_count" -eq 0 ]; then
  printf '\033[32m%s passed\033[0m\n' "$pass_count"
  exit 0
fi
printf '\033[31m%s failed\033[0m, %s passed\n' "$fail_count" "$pass_count"
exit 1
