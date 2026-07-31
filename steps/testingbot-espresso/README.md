# TestingBot App Automate - Espresso

[![Step changelog](https://shields.io/github/v/release/testingbot/bitrise-step-testingbot-espresso?include_prereleases&label=changelog&color=blueviolet)](https://github.com/testingbot/bitrise-step-testingbot-espresso/releases)

Runs your Espresso test suite on real Android devices and emulators at TestingBot.

<details>
<summary>Description</summary>

Uploads your app and Espresso test APK to [TestingBot](https://testingbot.com),
runs the suite on the devices you pick, streams progress into the build log,
and **fails the Bitrise build when a test fails**.

The JUnit report is downloaded and exported to Bitrise's own **Test Reports**
tab, so failures are visible without digging through the log.

If you don't set the app paths, the Step picks up the artifacts of the
preceding build Step automatically (`$BITRISE_APK_PATH` and
`$BITRISE_TEST_APK_PATH`).

### Configuring the Step

1. Add your TestingBot **key** and **secret** as Bitrise Secrets, and reference
   them from the `testingbot_key` / `testingbot_secret` inputs. Both are in the
   [TestingBot member area](https://testingbot.com/members/user/api).
2. Add an `Android Build` Step before this one that assembles both the app and
   the `androidTest` APK.
3. Set `device` to the device you want. Wildcards and regular expressions work:
   `Pixel 8`, `Pixel.*`, `Galaxy S2[34]`, or `*` for any available device.
4. Add `Deploy to Bitrise.io` after this Step to publish the test report.

### Requirements

This Step drives the [TestingBot CLI](https://github.com/testingbot/testingbotctl),
which needs **Node.js 20 or newer**. Every current Bitrise Stack ships one; if
yours doesn't, add an `Install Node.js` Step before this one.

### Troubleshooting

- **The build passes even though tests failed** — check that
  `fail_on_test_failure` is on (it is by default).
- **No results on the Test Reports tab** — add the `Deploy to Bitrise.io` Step
  after this one. It is what actually publishes what this Step exports.
- **`Could not find the test bundle`** — your `Android Build` Step needs to
  build the `androidTest` variant so `$BITRISE_TEST_APK_PATH` is set.

### Useful links

- [Espresso testing on TestingBot](https://testingbot.com/support/app-automate/espresso)
- [TestingBot CLI](https://github.com/testingbot/testingbotctl)
- [Available devices](https://testingbot.com/devices)

</details>

## 🧩 Get started

Add this step directly to your workflow in the [Bitrise Workflow Editor](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/steps/adding-steps-to-a-workflow.html).

You can also run this step directly with [Bitrise CLI](https://github.com/bitrise-io/bitrise).

### Run an Espresso suite and publish the results

The Step picks up both APKs from the preceding `Android Build` Step, and
`Deploy to Bitrise.io` publishes what it exports to the Test Reports tab:

```yaml
- android-build:
    inputs:
    - variant: debug
    - build_type: apk
- testingbot-espresso:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 8
- deploy-to-bitrise-io: {}
```

### Pick devices loosely so a busy device doesn't block the build

`device` takes wildcards and regular expressions:

```yaml
- testingbot-espresso:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel.*
    - platform_version: "14"
```

Use `*` for any available device, `Galaxy S2[34]` for a small set, or
`^Galaxy(?!.*23).*$` to exclude one.

### Smoke tests on pull requests, the full suite on main

```yaml
workflows:
  pr:
    steps:
    - android-build: {}
    - testingbot-espresso:
        inputs:
        - testingbot_key: $TESTINGBOT_KEY
        - testingbot_secret: $TESTINGBOT_SECRET
        - device: Pixel 8
        - test_name: Smoke tests
        - filter_annotation: com.example.SmokeTest
    - deploy-to-bitrise-io: {}

  nightly:
    steps:
    - android-build: {}
    - testingbot-espresso:
        inputs:
        - testingbot_key: $TESTINGBOT_KEY
        - testingbot_secret: $TESTINGBOT_SECRET
        - device: Samsung Galaxy S24
        - real_device: "true"
        - test_name: Full regression
    - deploy-to-bitrise-io: {}
```

### Report without failing the build

Useful while a suite is still flaky. The Step stays green and you decide what to
do with the result:

```yaml
- testingbot-espresso:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 8
    - fail_on_test_failure: "false"
- script:
    title: Warn on failures
    inputs:
    - content: |-
        #!/usr/bin/env bash
        if [ "$TESTINGBOT_TEST_STATUS" = "failed" ]; then
          echo "Espresso tests failed -- see the Test Reports tab."
        fi
```

### Test against a staging environment

`tunnel` opens a TestingBot Tunnel for the duration of the run, so the app on the
device can reach a host that isn't publicly routable:

```yaml
- testingbot-espresso:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 8
    - tunnel: "true"
```

### Run several device configurations in one Workflow

Give each Step a distinct `test_name` so their reports get their own tab:

```yaml
- testingbot-espresso:
    title: Espresso on Android 13
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 7
    - platform_version: "13"
    - test_name: Android 13
- testingbot-espresso:
    title: Espresso on Android 14
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 8
    - platform_version: "14"
    - test_name: Android 14
- deploy-to-bitrise-io: {}
```


## ⚙️ Configuration

<details>
<summary>Inputs</summary>

| Key | Description | Flags | Default |
| --- | --- | --- | --- |
| `testingbot_key` | Your TestingBot API key, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_KEY` |
| `testingbot_secret` | Your TestingBot API secret, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_SECRET` |
| `device` | The device to run the suite on.  Exact names work (`Pixel 8`), and so do wildcards and regular expressions, which is usually what you want in CI so a busy device doesn't block the build:  - `Pixel.*` — any Pixel - `Galaxy S2[34]` — a Galaxy S23 or S24 - `^Galaxy(?!.*23).*$` — any Galaxy that isn't an S23 - `*` — any available device  See the [device list](https://testingbot.com/devices). | required | `*` |
| `app_path` | Path to the application APK.  Leave empty to use `$BITRISE_APK_PATH` from the preceding `Android Build` Step. |  |  |
| `test_app_path` | Path to the APK holding your Espresso tests.  Leave empty to use `$BITRISE_TEST_APK_PATH` from the preceding `Android Build` Step. That Step needs to build the `androidTest` variant for this to be set. |  |  |
| `platform_version` | Android OS version to run on, for example `12`, `13` or `14`. Leave empty to let TestingBot choose. |  |  |
| `real_device` | Run on a physical device. Emulators are faster and cheaper for most suites; real devices matter for hardware-dependent behaviour. |  | `false` |
| `tablet_only` | Only allocate tablet devices. |  | `false` |
| `phone_only` | Only allocate phone devices. |  | `false` |
| `locale` | Device locale, for example `en_US` or `de_DE`. |  |  |
| `language` | App language as an ISO 639-1 code, for example `en` or `de`. |  |  |
| `timezone` | Device time zone, for example `Europe/Brussels`. |  |  |
| `build_name` | Identifier used to group the test sessions of one build together in the TestingBot dashboard. Defaults to the Bitrise app title and build number. |  | `$BITRISE_APP_TITLE - $BITRISE_BUILD_NUMBER` |
| `test_name` | Shown in the TestingBot dashboard, and used as the tab name on Bitrise's Test Reports page. Give parallel Steps distinct names so their reports don't collide. | required | `Espresso` |
| `test_runner` | Custom instrumentation runner, if you don't use the default `androidx.test.runner.AndroidJUnitRunner`. |  |  |
| `filter_size` | Comma-separated list of test sizes to run, for example `small,medium`. |  |  |
| `fail_on_test_failure` | When enabled (the default) a failing test fails the Step, and so the build.  Turn it off for a report-only run — the Step then succeeds regardless, and you can branch on the exported `$TESTINGBOT_TEST_STATUS`. | required | `true` |
| `run_async` | Start the run and return without waiting for it to finish.  Nothing is polled, no report is downloaded, and the Step cannot fail on a test failure — check the TestingBot dashboard instead. |  | `false` |
| `filter_class` | Run only the tests in these classes, for example `com.example.LoginTest,com.example.HomeTest`. |  |  |
| `filter_not_class` | Comma-separated, fully qualified class names to skip. |  |  |
| `filter_package` | Comma-separated package names. |  |  |
| `filter_not_package` | Comma-separated package names to skip. |  |  |
| `filter_annotation` | Comma-separated annotations, for example `com.example.SmokeTest`. |  |  |
| `filter_not_annotation` | Comma-separated annotations to skip. |  |  |
| `throttle_network` | Simulate a slower network: `4G`, `3G`, `Edge` or `airplane`. |  |  |
| `geo_location` | Route device traffic through a country, as an ISO code such as `US` or `DE`. |  |  |
| `tunnel` | Starts a TestingBot Tunnel for the duration of the run, so the app can reach a staging environment that isn't publicly routable.  Cannot be combined with `run_async`. |  | `false` |
| `tunnel_identifier` | Identifier of the tunnel to use. Set it when you run several tunnels in parallel, or to reuse a tunnel opened by the `TestingBot Tunnel` Step. |  |  |
| `export_to_test_reports` | Downloads the JUnit report and lays it out for Bitrise's Test Reports add-on.  You still need the `Deploy to Bitrise.io` Step afterwards — that Step is what uploads what this one exports. |  | `true` |
| `report_output_dir` | Directory the JUnit report is downloaded into. Defaults to a temporary directory. The path is exported as `$TESTINGBOT_JUNIT_REPORT_PATH`. |  |  |
| `cli_version` | The [TestingBot CLI](https://github.com/testingbot/testingbotctl) version this Step runs. Pinned so builds stay reproducible; set `latest` to always take the newest release. | required | `1.1.1` |
| `additional_args` | Appended verbatim to the `testingbot espresso` command, so you can use a CLI option this Step doesn't expose yet without waiting for a release.  See `npx @testingbot/cli espresso --help`. |  |  |
| `quiet` | Suppress the CLI's live progress output. |  | `false` |
</details>

<details>
<summary>Outputs</summary>

| Environment Variable | Description |
| --- | --- |
| `TESTINGBOT_TEST_STATUS` | `passed` or `failed`. Useful when `fail_on_test_failure` is off and you want to branch on the result yourself. |
| `TESTINGBOT_BUILD_NAME` | The build identifier the sessions were grouped under. |
| `TESTINGBOT_JUNIT_REPORT_PATH` | Path to the downloaded JUnit XML report. |
</details>

## 🙋 Contributing

We welcome [pull requests](https://github.com/testingbot/bitrise-step-testingbot-espresso/pulls) and [issues](https://github.com/testingbot/bitrise-step-testingbot-espresso/issues) against this repository.

For pull requests, work on your changes in a forked repository and use the Bitrise CLI to [run step tests locally](https://docs.bitrise.io/en/bitrise-ci/bitrise-cli/running-your-first-local-build-with-the-cli.html).

This Step is developed in the
[testingbot-bitrise](https://github.com/testingbot/testingbot-bitrise) monorepo
alongside the other TestingBot Steps, and mirrored into this repository on
release. **Please open pull requests against the monorepo**, not against the
mirror — changes pushed here are overwritten on the next release.

### Running the tests

The monorepo holds an offline suite that runs every Step against a mock of the
TestingBot API, so it needs no credentials:

```bash
tests/run.sh
```

The live check lives here, in `bitrise.yml`. It performs a real upload, so it
needs a TestingBot account:

```bash
bitrise run test
```

It reads `TESTINGBOT_KEY`, `TESTINGBOT_SECRET` and `SAMPLE_APP_URL` — put them in
a git-ignored `.bitrise.secrets.yml`. `SAMPLE_APP_URL` must point at a real
`.apk` or `.ipa`; TestingBot parses the binary, so a placeholder file is
rejected.

### Before opening a pull request

```bash
scripts/build.sh --check   # shared helpers are in sync (run from the monorepo)
shellcheck -x step.sh
bitrise run audit-this-step
bitrise run generate_readme
```

`README.md` is generated from `step.yml` plus the files in `docs/` — edit those,
never the README itself.

### Reporting a problem

Open an issue with the Bitrise build log (with credentials redacted) and the
Stack you are running on.


Learn more about developing steps:

- [Create your own step](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/developing-your-own-bitrise-step/developing-a-new-step.html)
