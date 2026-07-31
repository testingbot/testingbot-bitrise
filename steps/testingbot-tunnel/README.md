# TestingBot Tunnel

[![Step changelog](https://shields.io/github/v/release/testingbot/bitrise-step-testingbot-tunnel?include_prereleases&label=changelog&color=blueviolet)](https://github.com/testingbot/bitrise-step-testingbot-tunnel/releases)

Starts a TestingBot Tunnel so your tests can reach a local or staging environment.

<details>
<summary>Description</summary>

Starts a [TestingBot Tunnel](https://testingbot.com/support/other/tunnel) in the
background and waits until it is genuinely ready, so the devices in
TestingBot's cloud can reach an app that isn't publicly routable — a staging
host, a service on the build machine, or anything behind your firewall.

Pair it with the **TestingBot Tunnel Stop** Step at the end of the Workflow.
Bitrise has no post-build hook, so the tunnel has to be shut down by a Step
that always runs.

You only need this for Appium and Selenium tests. The **Espresso**, **XCUITest**
and **Maestro** Steps can open their own tunnel with their `tunnel` input.

### Configuring the Step

1. Add your TestingBot **key** and **secret** as Bitrise Secrets, and reference
   them from the `testingbot_key` / `testingbot_secret` inputs.
2. Add this Step before the Step that runs your tests.
3. Add **TestingBot Tunnel Stop** as the last Step of the Workflow.
4. In your tests, set `tunnelIdentifier` inside `tb:options` to the exported
   `$TESTINGBOT_TUNNEL_IDENTIFIER`.

### Requirements

The tunnel is a Java program and needs **Java 11 or newer** on the Stack. Most
Android Stacks ship a JDK; on a plain macOS Stack you may need an
`Install Java` Step first.

### Troubleshooting

If the tunnel fails to start, the Step prints the full tunnel log — that log
answers nearly every tunnel question. Raise `ready_timeout` on a slow network.

### Useful links

- [TestingBot Tunnel](https://testingbot.com/support/other/tunnel)
- [Tunnel command line reference](https://testingbot.com/support/tunnel/commandline)
- [Running multiple tunnels](https://testingbot.com/support/tunnel/multiple)

</details>

## 🧩 Get started

Add this step directly to your workflow in the [Bitrise Workflow Editor](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/steps/adding-steps-to-a-workflow.html).

You can also run this step directly with [Bitrise CLI](https://github.com/bitrise-io/bitrise).

### Test a staging environment with Appium

Start the tunnel, run the tests, stop the tunnel — the stop Step is configured to
run even if the tests fail:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
- script:
    title: Run Appium tests
    inputs:
    - content: |-
        #!/usr/bin/env bash
        set -eo pipefail
        npm test
- testingbot-tunnel-stop: {}
```

In your test capabilities, route the session through the tunnel:

```javascript
const capabilities = {
  platformName: 'Android',
  'appium:deviceName': 'Pixel 9',
  'appium:app': process.env.TESTINGBOT_APP_URL,
  'tb:options': {
    tunnelIdentifier: process.env.TESTINGBOT_TUNNEL_IDENTIFIER,
    build: `Bitrise #${process.env.BITRISE_BUILD_NUMBER}`,
  },
};
```

### Reach a server running on the build machine

```yaml
- script:
    title: Start the app under test
    inputs:
    - content: |-
        #!/usr/bin/env bash
        npm run start:ci &
        sleep 5
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
- script:
    title: Run tests against http://localhost:3000
    inputs:
    - content: npm test
- testingbot-tunnel-stop: {}
```

### Name the tunnel

The default already keeps concurrent Bitrise builds apart. Set it explicitly
when several tunnels run inside one build:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - tunnel_identifier: staging-$BITRISE_BUILD_NUMBER
    - ready_timeout: "180"
```

### Diagnose a tunnel that won't connect

The log is printed automatically when the tunnel fails to start. To see it on a
successful run too, raise the level and ask the stop Step to print it:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - log_level: debug
- testingbot-tunnel-stop:
    inputs:
    - print_log: "true"
```

### You may not need this Step

The Espresso, XCUITest and Maestro Steps open their own tunnel:

```yaml
- testingbot-espresso:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 8
    - tunnel: "true"
```


## ⚙️ Configuration

<details>
<summary>Inputs</summary>

| Key | Description | Flags | Default |
| --- | --- | --- | --- |
| `testingbot_key` | Your TestingBot API key, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_KEY` |
| `testingbot_secret` | Your TestingBot API secret, from the [member area](https://testingbot.com/members/user/api).  Store it as a Bitrise Secret and reference it here. | required, sensitive | `$TESTINGBOT_SECRET` |
| `tunnel_identifier` | Names the tunnel so tests can ask for it explicitly, and so several tunnels can run in parallel without colliding.  Pass the same value as `tunnelIdentifier` inside `tb:options` in your test capabilities. The default keeps concurrent Bitrise builds apart. | required | `bitrise-$BITRISE_BUILD_NUMBER` |
| `ready_timeout` | Maximum seconds to wait for the tunnel to signal that it is ready before failing the Step. The Step watches the tunnel's own ready file rather than its console output, so this is a real readiness check. | required | `120` |
| `log_level` | The tunnel's log level. The log is printed automatically if the tunnel fails to start; raise this to `debug` when diagnosing a connection problem. | required | `info` |
| `additional_args` | Appended verbatim to the tunnel command line, for options this Step doesn't expose — for example `--fast-fail-regexps`, `--proxy`, `--pac` or `--dns`.  See the [command line reference](https://testingbot.com/support/tunnel/commandline). |  |  |
| `download_url` | The tunnel archive to download. Point this at an internal mirror if your build machines can't reach testingbot.com directly. | required | `https://testingbot.com/downloads/testingbot-tunnel.zip` |
| `download_sha256` | SHA-256 of the tunnel archive. When set, the Step refuses to run a download that doesn't match.  Leave empty to skip verification — the download still happens over HTTPS. Set it if you pin a specific tunnel build via `download_url`. |  |  |
</details>

<details>
<summary>Outputs</summary>

| Environment Variable | Description |
| --- | --- |
| `TESTINGBOT_TUNNEL_IDENTIFIER` | Pass this as `tunnelIdentifier` inside `tb:options` in your test capabilities to route the session through this tunnel. |
| `TESTINGBOT_TUNNEL_PID` | PID of the running tunnel, used by the Tunnel Stop Step. |
| `TESTINGBOT_TUNNEL_LOG_PATH` | Path to the tunnel's log file. |
| `TESTINGBOT_TUNNEL_READY_FILE` | The file the tunnel touches once it is ready. |
</details>

## 🙋 Contributing

We welcome [pull requests](https://github.com/testingbot/bitrise-step-testingbot-tunnel/pulls) and [issues](https://github.com/testingbot/bitrise-step-testingbot-tunnel/issues) against this repository.

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
