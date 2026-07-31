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
  xcuitest     needs SAMPLE_APP_IPA and SAMPLE_TEST_BUNDLE (build them yourself)
  maestro      needs SAMPLE_FLOWS (a Maestro flows directory)
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

xcuitest | maestro | tunnel)
  step_dir="${REPO_ROOT}/steps/testingbot-${target}"
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
