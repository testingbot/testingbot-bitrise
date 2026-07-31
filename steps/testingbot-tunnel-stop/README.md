# TestingBot Tunnel Stop

[![Step changelog](https://shields.io/github/v/release/testingbot/bitrise-step-testingbot-tunnel-stop?include_prereleases&label=changelog&color=blueviolet)](https://github.com/testingbot/bitrise-step-testingbot-tunnel-stop/releases)

Stops a TestingBot Tunnel started earlier in the Workflow.

<details>
<summary>Description</summary>

Shuts down the tunnel that the **TestingBot Tunnel** Step started.

This Step is configured with `is_always_run`, so it also runs when an earlier
Step failed — otherwise a failing test Step would leave the tunnel running for
the rest of the build. It is also skippable, so a problem shutting the tunnel
down never turns a green build red.

Bitrise has no post-build hook, which is why stopping the tunnel is its own
Step rather than something the start Step could arrange.

### Configuring the Step

Add it as the **last** Step of the Workflow. With the defaults it picks up
`$TESTINGBOT_TUNNEL_PID` from the start Step, so there is normally nothing to
configure.

### Useful links

- [TestingBot Tunnel](https://testingbot.com/support/other/tunnel)

</details>

## 🧩 Get started

Add this step directly to your workflow in the [Bitrise Workflow Editor](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/steps/adding-steps-to-a-workflow.html).

You can also run this step directly with [Bitrise CLI](https://github.com/bitrise-io/bitrise).

### Stop the tunnel at the end of the Workflow

With the defaults there is nothing to configure — it picks up
`$TESTINGBOT_TUNNEL_PID` from the start Step:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
- script:
    title: Run tests
    inputs:
    - content: npm test
- testingbot-tunnel-stop: {}
```

Because the Step is marked `is_always_run`, the tunnel is still closed when the
test Step fails.

### Always print the tunnel log

Useful when tests behave oddly but the tunnel didn't fail outright:

```yaml
- testingbot-tunnel-stop:
    inputs:
    - print_log: "true"
```

### Give a stubborn tunnel longer to exit

The Step asks the tunnel to stop, waits, then forces it:

```yaml
- testingbot-tunnel-stop:
    inputs:
    - shutdown_timeout: "60"
```


## ⚙️ Configuration

<details>
<summary>Inputs</summary>

| Key | Description | Flags | Default |
| --- | --- | --- | --- |
| `tunnel_pid` | Exported by the **TestingBot Tunnel** Step. Leave the default unless you started the tunnel some other way. |  | `$TESTINGBOT_TUNNEL_PID` |
| `tunnel_log_path` | Log file to print when the tunnel didn't shut down cleanly. |  | `$TESTINGBOT_TUNNEL_LOG_PATH` |
| `print_log` | The log is printed automatically when something goes wrong. Turn this on to always see it, which is useful when diagnosing a connection problem that didn't stop the tunnel outright. |  | `false` |
| `shutdown_timeout` | The Step asks the tunnel to stop, waits this long for it to exit, then sends `SIGKILL`. | required | `30` |
</details>

<details>
<summary>Outputs</summary>
There are no outputs defined in this step
</details>

## 🙋 Contributing

We welcome [pull requests](https://github.com/testingbot/bitrise-step-testingbot-tunnel-stop/pulls) and [issues](https://github.com/testingbot/bitrise-step-testingbot-tunnel-stop/issues) against this repository.

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
