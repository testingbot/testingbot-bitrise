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
