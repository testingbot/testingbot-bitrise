# TestingBot Steps for Bitrise

The [Bitrise](https://bitrise.io) Steps for [TestingBot](https://testingbot.com):
upload your app, run Espresso / XCUITest / Maestro suites on real devices, and
open a tunnel to a staging environment — from a Bitrise Workflow.

| Step | What it does |
| --- | --- |
| [`testingbot-upload-app`](steps/testingbot-upload-app) | Uploads an app to TestingBot storage, exports its `tb://` identifier |
| [`testingbot-espresso`](steps/testingbot-espresso) | Runs an Espresso suite on TestingBot devices |
| [`testingbot-xcuitest`](steps/testingbot-xcuitest) | Runs an XCUITest suite on TestingBot devices |
| [`testingbot-maestro`](steps/testingbot-maestro) | Runs Maestro flows on TestingBot devices |
| [`testingbot-tunnel`](steps/testingbot-tunnel) | Starts a TestingBot Tunnel |
| [`testingbot-tunnel-stop`](steps/testingbot-tunnel-stop) | Stops the tunnel; always runs |

All six are at `1.0.0` and unpublished — see [docs/RELEASING.md](docs/RELEASING.md).

Two things these Steps do that no competitor's Bitrise Step does today: they
**fail the build when tests fail**, and they export results to Bitrise's native
**Test Reports** tab.

The three test Steps wrap [`@testingbot/cli`](https://github.com/testingbot/testingbotctl),
which already handles upload, triggering, live progress, JUnit reports, sharding
and retries. The Step's job is Bitrise ergonomics: artifact auto-detection,
readable inputs, actionable errors, and turning the result into a build status.

## Layout

This is a development monorepo. Each `steps/<id>/` directory is a complete,
self-contained Bitrise Step, and is mirrored to its own public repository on
release — the Bitrise StepLib requires `step.yml` at the root of the repository
it references.

```
steps/<id>/           one Step: step.yml, step.sh, bitrise.yml, README.md, docs/
lib/testingbot.bash   shared bash helpers, inlined into each step.sh
shared/               files copied verbatim into every Step (docs/contributing.md)
scripts/build.sh      sync shared sources into each Step
scripts/gen-readme.sh regenerate READMEs with Bitrise's steps-readme-generator
scripts/publish.sh    mirror one Step to its own repo, tag it, print share commands
scripts/audit-all.sh  every local check in one command
tests/                offline test suite, runs the Steps against mocks
```

Generated, so never edit by hand:

- the inlined library between the markers in each `step.sh` — `scripts/build.sh`
- each Step's `LICENSE`, `.gitignore` and `docs/contributing.md` — `scripts/build.sh`
- each Step's `README.md` — `scripts/gen-readme.sh`, which runs Bitrise's own
  `steps-readme-generator` from `step.yml` + `docs/examples.md` +
  `docs/contributing.md`

Edit the source, then re-run the relevant script. `scripts/build.sh --check`
fails if the inlined sources are stale.

`.yamllint.yml` and `.ymlfmt` are copied verbatim from
[`bitrise-steplib/steps-check`](https://github.com/bitrise-steplib/steps-check) —
the StepLib lints every `step.yml` against them, so keep them in sync with
upstream rather than editing them. To reformat after editing YAML by hand:

```bash
go run github.com/google/yamlfmt/cmd/yamlfmt@v0.21.0 \
  -conf .ymlfmt -match_type doublestar -exclude '_tmp/**,.git/**' '**/*.yml'
```

## Working on a Step

```bash
scripts/audit-all.sh        # everything below, in one command
tests/run.sh                # offline tests only (no credentials needed)
scripts/build.sh            # after editing lib/testingbot.bash
scripts/gen-readme.sh       # after editing step.yml or docs/
```

`audit-all.sh` runs the sync check, shellcheck, yamllint against Bitrise's own
config, `stepman audit` and `bitrise validate` per Step, and the offline suite.

Before a release, also run the full Bitrise linter per Step — it is what StepLib
CI runs, and it clones a repo each time so it is too slow for every edit:

```bash
cd steps/<id> && bitrise run check
```

The offline suite runs each `step.sh` against stand-ins — `tests/mock_api.py` for
the REST API, and `tests/stubs/` for `npx`, `node` and `java` — so it needs no
account and spends no device minutes. The stubs record the argument vector each
Step builds, which is what lets the tests assert on flag mapping and drive the
CLI's exit code to check how a test failure becomes a build result.

Live checks live in each Step's own `bitrise.yml` `test` workflow and do run real
tests on real devices. They need credentials and sample artifacts; see the
`app.envs` block at the top of each one.

For the `step.yml` audit and the live workflows you need the Bitrise CLI:

```bash
brew install bitrise && bitrise setup
```

## Releasing

See [docs/RELEASING.md](docs/RELEASING.md).

## License

MIT — see [LICENSE](LICENSE).
