# TestingBot App Upload

[![Step changelog](https://shields.io/github/v/release/testingbot/bitrise-step-testingbot-app-upload?include_prereleases&label=changelog&color=blueviolet)](https://github.com/testingbot/bitrise-step-testingbot-app-upload/releases)

Uploads an Android or iOS app to TestingBot storage and exports its tb:// app URL.

<details>
<summary>Description</summary>

Uploads your app (`.apk`, `.aab`, `.ipa`, `.app`, `.zip`) to [TestingBot](https://testingbot.com)
storage and exports the resulting `tb://` identifier, so later Steps and your
Appium tests can use it straight away.

If you don't set an app path, the Step picks up the artifact of the preceding
build Step automatically (`$BITRISE_APK_PATH`, `$BITRISE_AAB_PATH`,
`$BITRISE_IPA_PATH` or `$BITRISE_APP_DIR_PATH`).

### Configuring the Step

1. Add your TestingBot **key** and **secret** as Bitrise Secrets, and reference
   them from the `testingbot_key` / `testingbot_secret` inputs. You can find
   both in the [TestingBot member area](https://testingbot.com/members/user/api).
2. Add this Step after the Step that builds your app.
3. Use the exported `$TESTINGBOT_APP_URL` as the `appium:app` capability in
   your tests.

### Keeping a stable app identifier

By default every upload gets a fresh `tb://` identifier, which means your test
code has to read `$TESTINGBOT_APP_URL` from the environment. If you would
rather hard-code the identifier once and never touch it again, set `app_key` to
a name of your choice — each build then replaces the binary stored under that
name while `tb://<your-name>` stays the same.

### Troubleshooting

- **HTTP 401** — the key/secret pair is wrong, or the Secret isn't exposed to
  the Workflow.
- **HTTP 403** — the account is read-only; check the subscription state.
- Uploads are **deleted automatically after 62 days**. Re-upload on each build
  (which is what this Step is for) rather than relying on an old identifier.

### Useful links

- [TestingBot REST API](https://testingbot.com/support/api)
- [Uploading an app](https://testingbot.com/support/app-automate/help/upload)
- [Appium on TestingBot](https://testingbot.com/support/app-automate/appium)

</details>

## 🧩 Get started

Add this step directly to your workflow in the [Bitrise Workflow Editor](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/steps/adding-steps-to-a-workflow.html).

You can also run this step directly with [Bitrise CLI](https://github.com/bitrise-io/bitrise).

### Upload an Android build

The Step picks up the artifact from the preceding build Step on its own:

```yaml
- android-build: {}
- testingbot-upload-app:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
```

### Upload an iOS build and run Appium against it

```yaml
- xcode-archive: {}
- testingbot-upload-app:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
- script:
    title: Run Appium tests
    inputs:
    - content: |-
        #!/usr/bin/env bash
        set -eo pipefail
        # $TESTINGBOT_APP_URL holds the tb:// identifier of the app just uploaded.
        npm test
```

In your test code, use it as the `appium:app` capability:

```javascript
const capabilities = {
  platformName: 'iOS',
  'appium:deviceName': 'iPhone 15',
  'appium:platformVersion': '18.0',
  'appium:app': process.env.TESTINGBOT_APP_URL,
  'tb:options': { build: `Bitrise #${process.env.BITRISE_BUILD_NUMBER}` },
};
```

### Keep one identifier across every build

Set `app_key` and the identifier never changes, so you can hard-code
`tb://nightly-android` in your tests instead of threading an environment
variable through:

```yaml
- testingbot-upload-app:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - app_key: nightly-android
```

### Upload a specific file

```yaml
- testingbot-upload-app:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - apk_ipa_filepath: $BITRISE_SOURCE_DIR/build/outputs/apk/debug/app-debug.apk
```

### Let TestingBot fetch the app instead of uploading it

If the artifact is already reachable over HTTPS, skip pushing it out of the
build machine a second time:

```yaml
- testingbot-upload-app:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - app_url: https://example.com/builds/app-debug.apk
```

### Don't wait for the version and icon

TestingBot reads the app's version, minimum OS version and icon out of the
binary in the background, and the Step waits for that to finish so
`$TESTINGBOT_APP_VERSION` is trustworthy. If you only need the identifier,
skip the wait:

```yaml
- testingbot-upload-app:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - wait_for_processing: "false"
```

`$TESTINGBOT_APP_URL` is ready to test with immediately either way;
`$TESTINGBOT_APP_STATE` tells you whether the rest of the metadata had landed
(`DONE`) or not yet (`PROCESSING`).


## ⚙️ Configuration

<details>
<summary>Inputs</summary>

| Key | Description | Flags | Default |
| --- | --- | --- | --- |
| `testingbot_key` | Your TestingBot API key, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_KEY` |
| `testingbot_secret` | Your TestingBot API secret, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_SECRET` |
| `apk_ipa_filepath` | Local path to the app binary (`.apk`, `.aab`, `.ipa`, `.app`, `.zip`).  Leave empty to use the artifact produced by the preceding build Step. The Step looks at, in order:  - `$BITRISE_APK_PATH` - `$BITRISE_AAB_PATH` - `$BITRISE_IPA_PATH` - `$BITRISE_APP_DIR_PATH` |  |  |
| `app_url` | A public `https://` URL that TestingBot downloads the binary from, instead of this Step uploading a local file.  Useful when the artifact already lives somewhere reachable — it saves pushing the binary out of the build machine a second time. Takes precedence over `apk_ipa_filepath`. |  |  |
| `app_key` | When set, the app is stored under this name and the exported identifier is always `tb://<app_key>`, no matter how often you re-upload.  That lets you hard-code the `appium:app` capability in your test code once. Leave empty to get a new identifier per upload. |  |  |
| `wait_for_processing` | TestingBot extracts an uploaded app's version, minimum OS version and icon in the background. The stored app reports `state: PROCESSING` until that finishes, then `state: DONE`.  With this enabled the Step polls until the state is `DONE`, so `$TESTINGBOT_APP_VERSION` is either the real version or a genuine absence — not just "not extracted yet".  Turn it off if you only need `$TESTINGBOT_APP_URL` and don't want to wait. The identifier is usable for testing either way; check `$TESTINGBOT_APP_STATE` to see which you got. | required | `true` |
| `processing_timeout` | How long to wait for `state` to become `DONE`, in seconds. Extraction normally takes a few seconds.  Running out of time is **not** a Step failure — the app is uploaded and testable regardless. The Step warns, exports `$TESTINGBOT_APP_STATE=PROCESSING` and carries on.  Only used when `wait_for_processing` is enabled. | required | `300` |
</details>

<details>
<summary>Outputs</summary>

| Environment Variable | Description |
| --- | --- |
| `TESTINGBOT_APP_URL` | The `tb://...` identifier of the uploaded app. Pass it as the `appium:app` capability, or to one of the TestingBot App Automate Steps. |
| `TESTINGBOT_APP_ID` | The numeric storage ID of the uploaded app. |
| `TESTINGBOT_APP_VERSION` | The `versionName` (Android) or `CFBundleShortVersionString` (iOS) that TestingBot extracted from the uploaded binary. |
| `TESTINGBOT_APP_TYPE` | The platform TestingBot detected, for example `ANDROID` or `IOS`. |
| `TESTINGBOT_APP_STATE` | `DONE` once TestingBot has extracted the app's version, minimum OS version and icon; `PROCESSING` while that is still running.  This is only ever `PROCESSING` when `wait_for_processing` is off or its timeout ran out. The app is uploaded and testable in either case. |
| `TESTINGBOT_APP_DOWNLOAD_URL` | Signed URL to download the stored binary again. |
</details>

## 🙋 Contributing

We welcome [pull requests](https://github.com/testingbot/bitrise-step-testingbot-app-upload/pulls) and [issues](https://github.com/testingbot/bitrise-step-testingbot-app-upload/issues) against this repository.

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
