#!/usr/bin/env bash
#
# Run a Step's live `test` workflow against the real TestingBot service.
#
# Unlike tests/run.sh, this spends device minutes and needs credentials. It
# reads them from ONE .bitrise.secrets.yml at the repo root (git-ignored) rather
# than a copy per Step, and downloads the sample artifacts it needs.
#
#   scripts/e2e.sh espresso        # or: upload-app, xcuitest, maestro, tunnel
#   scripts/e2e.sh                 # list what each Step needs
#
# Credentials go in <repo root>/.bitrise.secrets.yml:
#
#   envs:
#   - TESTINGBOT_KEY: <your key>
#   - TESTINGBOT_SECRET: <your secret>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.bitrise/tools:${PATH}"

SECRETS="${REPO_ROOT}/.bitrise.secrets.yml"
FIXTURES="${REPO_ROOT}/.fixtures"

# The Espresso demo app ships prebuilt APKs, so no Gradle build is needed.
DEMO_RELEASE="https://github.com/testingbot/android-espresso-demo-app/releases/download/1.0.0"

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
usage: scripts/e2e.sh <step>

  upload-app   uploads a real app; needs credentials only
  espresso     runs the demo Espresso suite on a device
  xcuitest     builds testingbot/xcuitest-example-app for a device; needs Xcode
  maestro      runs tests/fixtures/maestro-flows against the demo app
  tunnel       opens a real tunnel; needs Java 11+ locally

Credentials: ${SECRETS}

  envs:
  - TESTINGBOT_KEY: <your key>
  - TESTINGBOT_SECRET: <your secret>
EOF
}

[ "$#" -ge 1 ] || {
  usage
  exit 1
}
target="$1"

[ -f "$SECRETS" ] || die "no credentials at ${SECRETS}

Create it with:

  envs:
  - TESTINGBOT_KEY: <your key>
  - TESTINGBOT_SECRET: <your secret>

It is git-ignored."

grep -q 'TESTINGBOT_KEY' "$SECRETS" || die "${SECRETS} has no TESTINGBOT_KEY"

# The XCUITest sample ships source only, so it has to be built here.
#
# It is built for a DEVICE destination, not the simulator: TestingBot runs
# XCUITest on real devices only, and a simulator build simply never produces a
# result. Signing is skipped because TestingBot re-signs uploaded .ipa files
# with its own provisioning profile.
# See https://testingbot.com/support/app-automate/help/app-resigning
XCUI_SAMPLE_REPO="https://github.com/testingbot/xcuitest-example-app"
XCUI_SRC="${FIXTURES}/xcuitest-example-app"
XCUI_DERIVED="${FIXTURES}/xcui-dd-device"
XCUI_PRODUCTS="${XCUI_DERIVED}/Build/Products/Debug-iphoneos"
XCUI_IPA="${FIXTURES}/xcuitest-sample.ipa"

build_xcuitest_sample() {
  command -v xcodebuild >/dev/null 2>&1 ||
    die "xcodebuild not found -- the XCUITest sample has to be built locally.
Install Xcode, or set SAMPLE_APP_PATH and SAMPLE_TEST_BUNDLE yourself."

  if [ ! -d "$XCUI_SRC" ]; then
    echo "  clone   xcuitest-example-app"
    git clone --depth 1 --quiet "$XCUI_SAMPLE_REPO" "$XCUI_SRC" ||
      die "could not clone ${XCUI_SAMPLE_REPO}"
  else
    echo "  cached  xcuitest-example-app"
  fi

  if [ -d "${XCUI_PRODUCTS}/xcuitest-sampleUITests-Runner.app" ]; then
    echo "  cached  device build"
  else
    echo "  build   xcuitest-sample for iOS devices (this takes a minute)"
    (cd "$XCUI_SRC" && xcodebuild build-for-testing \
      -project xcuitest-sample.xcodeproj \
      -scheme xcuitest-sample \
      -destination 'generic/platform=iOS' \
      -derivedDataPath "$XCUI_DERIVED" \
      CODE_SIGNING_ALLOWED=NO) >"${FIXTURES}/xcodebuild.log" 2>&1 || {
      tail -30 "${FIXTURES}/xcodebuild.log" >&2
      die "xcodebuild failed -- full log at ${FIXTURES}/xcodebuild.log"
    }

    [ -d "${XCUI_PRODUCTS}/xcuitest-sampleUITests-Runner.app" ] ||
      die "the build produced no *-Runner.app under ${XCUI_PRODUCTS}"
  fi

  # Wrap the app the way `Xcode Archive & Export` does, so the Step is handed
  # the same $BITRISE_IPA_PATH shape a real iOS Workflow would give it.
  if [ -s "$XCUI_IPA" ]; then
    echo "  cached  $(basename "$XCUI_IPA")"
  else
    echo "  package $(basename "$XCUI_IPA")"
    rm -rf "${FIXTURES}/Payload"
    mkdir -p "${FIXTURES}/Payload"
    cp -R "${XCUI_PRODUCTS}/xcuitest-sample.app" "${FIXTURES}/Payload/"
    (cd "$FIXTURES" && zip -qry --symlinks "$(basename "$XCUI_IPA")" Payload) ||
      die "could not package ${XCUI_IPA}"
    rm -rf "${FIXTURES}/Payload"
  fi
}

# fetch <url> <dest> -- download once, reuse afterwards.
fetch() {
  if [ -s "$2" ]; then
    echo "  cached  $(basename "$2")"
    return 0
  fi
  echo "  fetch   $(basename "$2")"
  mkdir -p "$(dirname "$2")"
  curl --fail --location --silent --show-error \
    --retry 3 --connect-timeout 10 --max-time 300 \
    --output "$2" "$1" || die "could not download $1"
}

case "$target" in
upload-app)
  step_dir="${REPO_ROOT}/steps/testingbot-upload-app"
  echo "==> Fixtures"
  # The upload Step's test workflow uses the remote-URL path, so it just needs
  # a public URL to a real binary.
  extra_envs=(--inventory "$SECRETS")
  export SAMPLE_APP_URL="${DEMO_RELEASE}/app-debug.apk"
  echo "  SAMPLE_APP_URL=${SAMPLE_APP_URL}"
  ;;

espresso)
  step_dir="${REPO_ROOT}/steps/testingbot-espresso"
  echo "==> Fixtures"
  fetch "${DEMO_RELEASE}/app-debug.apk" "${FIXTURES}/app-debug.apk"
  fetch "${DEMO_RELEASE}/app-debug-androidTest.apk" "${FIXTURES}/app-debug-androidTest.apk"
  extra_envs=(--inventory "$SECRETS")
  export SAMPLE_APP_APK="${FIXTURES}/app-debug.apk"
  export SAMPLE_TEST_APK="${FIXTURES}/app-debug-androidTest.apk"
  ;;

xcuitest)
  step_dir="${REPO_ROOT}/steps/testingbot-xcuitest"
  echo "==> Fixtures"
  build_xcuitest_sample
  extra_envs=(--inventory "$SECRETS")
  export SAMPLE_APP_PATH="$XCUI_IPA"
  export SAMPLE_TEST_BUNDLE="$XCUI_PRODUCTS"
  echo "  SAMPLE_APP_PATH=${SAMPLE_APP_PATH}"
  echo "  SAMPLE_TEST_BUNDLE=${SAMPLE_TEST_BUNDLE}"
  ;;

maestro)
  step_dir="${REPO_ROOT}/steps/testingbot-maestro"
  echo "==> Fixtures"
  fetch "${DEMO_RELEASE}/app-debug.apk" "${FIXTURES}/app-debug.apk"
  extra_envs=(--inventory "$SECRETS")
  export SAMPLE_APP="${FIXTURES}/app-debug.apk"
  # Checked in, not downloaded: these are hand-written against the demo app's
  # resource ids.
  export SAMPLE_FLOWS="${REPO_ROOT}/tests/fixtures/maestro-flows"
  echo "  SAMPLE_FLOWS=${SAMPLE_FLOWS}"
  ;;

tunnel)
  step_dir="${REPO_ROOT}/steps/testingbot-tunnel"
  extra_envs=(--inventory "$SECRETS")
  ;;

*)
  usage
  die "unknown step: ${target}"
  ;;
esac

echo
echo "==> bitrise run test  (steps/$(basename "$step_dir"))"
echo "    This runs on real devices and spends device minutes."
echo

cd "$step_dir"
exec bitrise run test "${extra_envs[@]}"
