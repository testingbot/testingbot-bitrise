# TestingBot App Automate - Maestro

[![Step changelog](https://shields.io/github/v/release/testingbot/bitrise-step-testingbot-maestro?include_prereleases&label=changelog&color=blueviolet)](https://github.com/testingbot/bitrise-step-testingbot-maestro/releases)

Runs your Maestro flows on real Android and iOS devices at TestingBot.

<details>
<summary>Description</summary>

Uploads your app and [Maestro](https://maestro.mobile.dev) flows to
[TestingBot](https://testingbot.com), runs them on the devices you pick,
streams progress into the build log, and **fails the Bitrise build when a flow
fails**.

The JUnit report is downloaded and exported to Bitrise's own **Test Reports**
tab, and screenshots, logs and video can be pulled down as build artifacts.

Works for both Android and iOS — the platform follows from the app you give it.

### Configuring the Step

1. Add your TestingBot **key** and **secret** as Bitrise Secrets, and reference
   them from the `testingbot_key` / `testingbot_secret` inputs. Both are in the
   [TestingBot member area](https://testingbot.com/members/user/api).
2. Point `flows` at your flow files — a directory, individual `.yaml` files,
   globs, or a `.zip`. One entry per line.
3. Set `device` to the device you want. Wildcards and regular expressions work:
   `Pixel 9`, `iPhone.*`, or `*` for any available device.
4. Add `Deploy to Bitrise.io` after this Step to publish the test report.

### Flows and subflows

Every top-level flow you pass runs as its own test. A **subflow** — one that
another flow pulls in with `runFlow` — should not be passed as a top-level
flow, or it runs twice. Keep subflows in their own directory and point `flows`
at the parent directory only; `runFlow` targets are bundled automatically.

### Requirements

This Step drives the [TestingBot CLI](https://github.com/testingbot/testingbotctl),
which needs **Node.js 20 or newer**. Every current Bitrise Stack ships one; if
yours doesn't, add an `Install Node.js` Step before this one.

### Troubleshooting

- **A flow ran twice** — it is both a top-level flow and a `runFlow` target.
  See "Flows and subflows" above.
- **No results on the Test Reports tab** — add the `Deploy to Bitrise.io` Step
  after this one. It is what actually publishes what this Step exports.

### Useful links

- [Maestro testing on TestingBot](https://testingbot.com/support/app-automate/maestro)
- [Maestro API reference](https://testingbot.com/support/app-automate/maestro/api)
- [TestingBot CLI](https://github.com/testingbot/testingbotctl)
- [Available devices](https://testingbot.com/devices)

</details>

## 🧩 Get started

Add this step directly to your workflow in the [Bitrise Workflow Editor](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/steps/adding-steps-to-a-workflow.html).

You can also run this step directly with [Bitrise CLI](https://github.com/bitrise-io/bitrise).

### Run Maestro flows and publish the results

```yaml
- android-build: {}
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
- deploy-to-bitrise-io: {}
```

### The same flows on iOS

Nothing changes but the app — the platform follows from it:

```yaml
- xcode-archive: {}
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: iPhone 16
- deploy-to-bitrise-io: {}
```

### Cut wall-clock time with sharding

Splits the flows across parallel device sessions:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - shard_split: "4"
```

### Several flow directories

One per line:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 9
    - flows: |-
        .maestro/smoke
        .maestro/checkout
        .maestro/onboarding
```

### Tags, and environment variables for the flows

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - include_tags: smoke,critical
    - exclude_tags: slow
    - flow_env: |-
        API_URL=https://staging.example.com
        FEATURE_FLAG_NEW_CHECKOUT=true
```

### Collect screenshots and video for failures

The zip lands in `$BITRISE_DEPLOY_DIR`, so `Deploy to Bitrise.io` attaches it to
the build:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - download_artifacts: failed
- deploy-to-bitrise-io: {}
```

### Retry genuinely flaky flows

Only the flows that failed are re-run, and the last attempt decides the result.
Prefer fixing the flow — this will also hide a real regression:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - retry: "1"
```


## ⚙️ Configuration

<details>
<summary>Inputs</summary>

| Key | Description | Flags | Default |
| --- | --- | --- | --- |
| `testingbot_key` | Your TestingBot API key, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_KEY` |
| `testingbot_secret` | Your TestingBot API secret, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_SECRET` |
| `flows` | Flow files, directories, `.zip` archives or glob patterns. Put one entry per line (a pipe-separated list works too):  ``` .maestro/smoke .maestro/checkout ```  Pass the directory holding your **top-level** flows. Subflows pulled in with `runFlow` are bundled automatically and should not be listed, or they run twice. | required | `.maestro` |
| `device` | The device to run the flows on.  Exact names work (`Pixel 9`, `iPhone 16`), and so do wildcards and regular expressions, which is usually what you want in CI so a busy device doesn't block the build:  - `Pixel.*` — any Pixel - `iPhone 1[56]` — an iPhone 15 or 16 - `*` — any available device  See the [device list](https://testingbot.com/devices). | required | `*` |
| `app_path` | Path to the app (`.apk`, `.ipa`, `.app` or `.zip`).  Leave empty to use the artifact of the preceding build Step — `$BITRISE_APK_PATH`, `$BITRISE_AAB_PATH`, `$BITRISE_IPA_PATH` or `$BITRISE_APP_DIR_PATH`, in that order. |  |  |
| `platform` | `Android` or `iOS`. Inferred from the app when left empty. |  |  |
| `platform_version` | OS version, for example `14` or `17.2`. |  |  |
| `real_device` | Run on a physical device rather than an emulator or simulator. |  | `false` |
| `orientation` | Screen orientation: PORTRAIT or LANDSCAPE. Device default when empty. |  |  |
| `locale` | Device locale, for example `en_US` or `de_DE`. |  |  |
| `timezone` | Device time zone, for example `Europe/Brussels`. |  |  |
| `groups` | Groups appear on the test in the TestingBot dashboard and are the way to label a run — for example `nightly` or `pr-checks`.  Note the Maestro command has no build identifier of its own, unlike the Espresso and XCUITest Steps. |  |  |
| `test_name` | Shown in the TestingBot dashboard, and used as the tab name on Bitrise's Test Reports page. Give parallel Steps distinct names so their reports don't collide. | required | `Maestro` |
| `include_tags` | Only run flows carrying these tags. Comma-separated. |  |  |
| `exclude_tags` | Skip flows carrying these tags. Comma-separated. |  |  |
| `flow_env` | Environment variables made available to your flows, one `KEY=VALUE` per line:  ``` API_URL=https://staging.example.com USER=demo ```  Don't put secrets here unless the value comes from a Bitrise Secret. |  |  |
| `fail_on_test_failure` | When enabled (the default) a failing flow fails the Step, and so the build.  Turn it off for a report-only run — the Step then succeeds regardless, and you can branch on the exported `$TESTINGBOT_TEST_STATUS`. | required | `true` |
| `shard_split` | Splits the flows over N parallel device sessions, which is the quickest way to cut wall-clock time on a large suite. `0` disables sharding. | required | `0` |
| `retry` | Re-runs only the flows that failed, as soon as they fail. The last attempt decides the result, consistently across the exit code, the TestingBot dashboard and the downloaded report.  Useful for genuinely flaky flows; it will also mask a real regression, so prefer fixing the flow. | required | `0` |
| `run_async` | Start the run and return without waiting for it to finish.  Nothing is polled, no report is downloaded, and the Step cannot fail on a flow failure — check the TestingBot dashboard instead. Cannot be combined with `tunnel` or `retry`. |  | `false` |
| `throttle_network` | Simulate a slower network: `4G`, `3G`, `Edge` or `airplane`. |  |  |
| `geo_country_code` | Route device traffic through a country, as an ISO code such as `US` or `DE`. |  |  |
| `tunnel` | Starts a TestingBot Tunnel for the duration of the run, so the app can reach a staging environment that isn't publicly routable.  Cannot be combined with `run_async`. |  | `false` |
| `tunnel_identifier` | Identifier of the tunnel to use.  Defaults to the tunnel opened by the `TestingBot Tunnel` Step earlier in the Workflow, which exports `$TESTINGBOT_TUNNEL_IDENTIFIER`. Set it explicitly only when you run several tunnels in parallel. |  | `$TESTINGBOT_TUNNEL_IDENTIFIER` |
| `export_to_test_reports` | Downloads the JUnit report and lays it out for Bitrise's Test Reports add-on.  You still need the `Deploy to Bitrise.io` Step afterwards — that Step is what uploads what this one exports. |  | `true` |
| `download_artifacts` | Downloads test artifacts as a zip:  - `none` — don't download anything - `failed` — only artifacts of failed flows - `all` — everything  The zip lands in `$BITRISE_DEPLOY_DIR`, so `Deploy to Bitrise.io` attaches it to the build. | required | `none` |
| `report_output_dir` | Directory the JUnit report is downloaded into. Defaults to a temporary directory. The path is exported as `$TESTINGBOT_JUNIT_REPORT_PATH`. |  |  |
| `maestro_version` | Pin the Maestro version used on the device. Leave empty for the default. |  |  |
| `maestro_config` | Path to a Maestro `config.yaml`. |  |  |
| `cli_version` | The [TestingBot CLI](https://github.com/testingbot/testingbotctl) version this Step runs. Pinned so builds stay reproducible; set `latest` to always take the newest release. | required | `1.1.1` |
| `additional_args` | Appended verbatim to the `testingbot maestro` command, so you can use a CLI option this Step doesn't expose yet without waiting for a release.  See `npx @testingbot/cli maestro --help`. |  |  |
| `quiet` | Suppress the CLI's live progress output. |  | `false` |
</details>

<details>
<summary>Outputs</summary>

| Environment Variable | Description |
| --- | --- |
| `TESTINGBOT_TEST_STATUS` | `passed` or `failed`. Useful when `fail_on_test_failure` is off and you want to branch on the result yourself. |
| `TESTINGBOT_JUNIT_REPORT_PATH` | Path to the downloaded JUnit XML report. |
| `TESTINGBOT_ARTIFACTS_PATH` | Directory holding the downloaded artifacts zip, when enabled. |
</details>

## 🙋 Contributing

We welcome [pull requests](https://github.com/testingbot/bitrise-step-testingbot-maestro/pulls) and [issues](https://github.com/testingbot/bitrise-step-testingbot-maestro/issues) against this repository.

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
