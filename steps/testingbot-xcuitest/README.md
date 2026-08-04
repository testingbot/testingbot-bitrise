# TestingBot App Automate - XCUITest

[![Step changelog](https://shields.io/github/v/release/testingbot/bitrise-step-testingbot-xcuitest?include_prereleases&label=changelog&color=blueviolet)](https://github.com/testingbot/bitrise-step-testingbot-xcuitest/releases)

Runs your XCUITest suite on real iOS devices and simulators at TestingBot.

<details>
<summary>Description</summary>

Uploads your app and XCUITest suite to [TestingBot](https://testingbot.com),
runs the suite on the devices you pick, streams progress into the build log,
and **fails the Bitrise build when a test fails**.

The JUnit report is downloaded and exported to Bitrise's own **Test Reports**
tab, so failures are visible without digging through the log.

### Configuring the Step

1. Add your TestingBot **key** and **secret** as Bitrise Secrets, and reference
   them from the `testingbot_key` / `testingbot_secret` inputs. Both are in the
   [TestingBot member area](https://testingbot.com/members/user/api).
2. Add an `Xcode Build for testing` Step before this one. It produces the test
   bundle this Step needs.
3. Set `device` to the device you want. Wildcards and regular expressions work:
   `iPhone 16`, `iPhone.*`, `iPhone 1[56]`, or `*` for any available device.
4. Add `Deploy to Bitrise.io` after this Step to publish the test report.

### About the test bundle

TestingBot expects the XCUITest suite as a zip containing the `*-Runner.app`.
`Xcode Build for testing` exports a **directory** instead, so this Step finds
the runner inside it and zips it for you. You can also point `test_app_path`
straight at a `.zip` or a `*-Runner.app` if you build it yourself.

### Requirements

This Step drives the [TestingBot CLI](https://github.com/testingbot/testingbotctl),
which needs **Node.js 20 or newer**. Every current Bitrise Stack ships one; if
yours doesn't, add an `Install Node.js` Step before this one.

### Troubleshooting

- **`No *-Runner.app was found`** — the `Xcode Build for testing` Step needs to
  build for a **device** destination, not a simulator, for a real-device run.
- **The build passes even though tests failed** — check that
  `fail_on_test_failure` is on (it is by default).
- **No results on the Test Reports tab** — add the `Deploy to Bitrise.io` Step
  after this one.

### Useful links

- [XCUITest on TestingBot](https://testingbot.com/support/xcuitest)
- [XCUITest test reports](https://testingbot.com/support/xcuitest/test-reports.html)
- [TestingBot CLI](https://github.com/testingbot/testingbotctl)
- [Available devices](https://testingbot.com/devices)

</details>

## 🧩 Get started

Add this step directly to your workflow in the [Bitrise Workflow Editor](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/steps/adding-steps-to-a-workflow.html).

You can also run this step directly with [Bitrise CLI](https://github.com/bitrise-io/bitrise).

### Run an XCUITest suite and publish the results

`Xcode Build for testing` produces the test bundle; this Step finds the
`*-Runner.app` inside it and zips it for TestingBot:

```yaml
- xcode-build-for-test:
    inputs:
    - destination: generic/platform=iOS
- testingbot-xcuitest:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: iPhone 16
    - real_device: "true"
- deploy-to-bitrise-io: {}
```

For a real-device run, build for a device destination
(`generic/platform=iOS`) rather than a simulator.

### Pick devices loosely so a busy device doesn't block the build

`device` takes wildcards and regular expressions:

```yaml
- testingbot-xcuitest:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: iPhone 1[56].*
    - platform_version: "18.0"
```

### iPad, in landscape

```yaml
- testingbot-xcuitest:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: iPad.*
    - tablet_only: "true"
    - orientation: LANDSCAPE
```

### Localized runs

```yaml
- testingbot-xcuitest:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: iPhone 16
    - locale: DE
    - language: de
    - timezone: Europe/Berlin
```

### Report without failing the build

Useful while a suite is still flaky:

```yaml
- testingbot-xcuitest:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: iPhone 16
    - fail_on_test_failure: "false"
- script:
    inputs:
    - content: |-
        #!/usr/bin/env bash
        if [ "$TESTINGBOT_TEST_STATUS" = "failed" ]; then
          echo "XCUITest failures -- see the Test Reports tab."
        fi
```

### Point at a prebuilt test bundle

If you build the zip yourself, hand it over directly:

```yaml
- testingbot-xcuitest:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: iPhone 16
    - app_path: $BITRISE_SOURCE_DIR/build/Example.ipa
    - test_app_path: $BITRISE_SOURCE_DIR/build/ExampleUITests.zip
```


## ⚙️ Configuration

<details>
<summary>Inputs</summary>

| Key | Description | Flags | Default |
| --- | --- | --- | --- |
| `testingbot_key` | Your TestingBot API key, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_KEY` |
| `testingbot_secret` | Your TestingBot API secret, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_SECRET` |
| `device` | The device to run the suite on.  Exact names work (`iPhone 16`), and so do wildcards and regular expressions, which is usually what you want in CI so a busy device doesn't block the build:  - `iPhone.*` — any iPhone - `iPhone 1[56]` — an iPhone 15 or 16 - `iPad.*` — any iPad - `*` — any available device  See the [device list](https://testingbot.com/devices). | required | `*` |
| `app_path` | Path to the application IPA.  Leave empty to use `$BITRISE_IPA_PATH` from the preceding `Xcode Archive & Export` Step, falling back to `$BITRISE_APP_DIR_PATH`. |  |  |
| `test_app_path` | The XCUITest suite. Accepts a `.zip`, a `*-Runner.app`, or the test bundle **directory** that `Xcode Build for testing` exports — in which case the Step finds the runner inside it and zips it for you.  Leave empty to use `$BITRISE_TEST_BUNDLE_PATH`. |  |  |
| `platform_version` | iOS version, for example `17.2` or `18.0`. |  |  |
| `real_device` | Run on a physical device. Simulators are faster and cheaper for most suites; real devices matter for hardware-dependent behaviour.  A real-device run needs an IPA built for a device destination. |  | `false` |
| `tablet_only` | Only allocate iPad devices. |  | `false` |
| `phone_only` | Only allocate iPhone devices. |  | `false` |
| `orientation` | Screen orientation: PORTRAIT or LANDSCAPE. Device default when empty. |  |  |
| `locale` | Device locale, for example `US` or `DE`. |  |  |
| `language` | App language as an ISO 639-1 code, for example `en` or `de`. |  |  |
| `timezone` | Device time zone, for example `Europe/Brussels`. |  |  |
| `build_name` | Identifier used to group the test sessions of one build together in the TestingBot dashboard.  Leave empty to name the build after the Bitrise app title and build number, for example `My App #42`. |  |  |
| `test_name` | Shown in the TestingBot dashboard, and used as the tab name on Bitrise's Test Reports page. Give parallel Steps distinct names so their reports don't collide. | required | `XCUITest` |
| `fail_on_test_failure` | When enabled (the default) a failing test fails the Step, and so the build.  Turn it off for a report-only run — the Step then succeeds regardless, and you can branch on the exported `$TESTINGBOT_TEST_STATUS`. | required | `true` |
| `run_async` | Start the run and return without waiting for it to finish.  Nothing is polled, no report is downloaded, and the Step cannot fail on a test failure — check the TestingBot dashboard instead. |  | `false` |
| `throttle_network` | Simulate a slower network: `4G`, `3G`, `Edge` or `airplane`. |  |  |
| `geo_location` | Route device traffic through a country, as an ISO code such as `US` or `DE`. |  |  |
| `tunnel` | Starts a TestingBot Tunnel for the duration of the run, so the app can reach a staging environment that isn't publicly routable.  Cannot be combined with `run_async`. |  | `false` |
| `tunnel_identifier` | Identifier of the tunnel to use. Set it when you run several tunnels in parallel, or to reuse a tunnel opened by the `TestingBot Tunnel` Step. |  |  |
| `export_to_test_reports` | Downloads the JUnit report and lays it out for Bitrise's Test Reports add-on.  You still need the `Deploy to Bitrise.io` Step afterwards — that Step is what uploads what this one exports. |  | `true` |
| `report_output_dir` | Directory the JUnit report is downloaded into. Defaults to a temporary directory. The path is exported as `$TESTINGBOT_JUNIT_REPORT_PATH`. |  |  |
| `cli_version` | The [TestingBot CLI](https://github.com/testingbot/testingbotctl) version this Step runs. Pinned so builds stay reproducible; set `latest` to always take the newest release. | required | `1.1.1` |
| `additional_args` | Appended verbatim to the `testingbot xcuitest` command, so you can use a CLI option this Step doesn't expose yet without waiting for a release.  See `npx @testingbot/cli xcuitest --help`. |  |  |
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

We welcome [pull requests](https://github.com/testingbot/bitrise-step-testingbot-xcuitest/pulls) and [issues](https://github.com/testingbot/bitrise-step-testingbot-xcuitest/issues) against this repository.

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
