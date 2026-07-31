# Releasing a Step

Publishing means two things: mirroring the Step into its own public repository
(the StepLib references a git URL whose **root** holds `step.yml`), and adding a
`step.yml` to the Bitrise StepLib via a pull request.

## Repositories

Three kinds of repository are involved, and all of them now exist:

| Repository | Role | Notes |
| --- | --- | --- |
| [`testingbot/testingbot-bitrise`](https://github.com/testingbot/testingbot-bitrise) | this monorepo — where the work happens | public, `main` |
| [`testingbot/bitrise-step-testingbot-app-upload`](https://github.com/testingbot/bitrise-step-testingbot-app-upload) | mirror of `steps/testingbot-upload-app` | predates the rest: default branch is **`master`**, and it carries the published `0.0.1` tag |
| `testingbot/bitrise-step-testingbot-{espresso,xcuitest,maestro,tunnel,tunnel-stop}` | the other five mirrors | public, empty until the first `git subtree push` |
| [`testingbot/bitrise-steplib`](https://github.com/testingbot/bitrise-steplib) | fork of the StepLib that `bitrise share` writes into | synced to upstream |

`scripts/publish.sh` asks each mirror for its own default branch, so the
`master`/`main` split between the old repo and the new ones is handled for you.

### Before each release

Resync the StepLib fork, or `bitrise share` builds its pull request against
stale history:

```bash
gh repo sync testingbot/bitrise-steplib --source bitrise-io/bitrise-steplib
export MY_STEPLIB_REPO_FORK_GIT_URL=https://github.com/testingbot/bitrise-steplib.git
```

### Also needed

- The Bitrise CLI: `brew install bitrise && bitrise setup`
- Push access to the mirrors and the fork.

## 1. Get the Step green

```bash
scripts/audit-all.sh                     # fast checks, no credentials needed
cd steps/<step-id> && bitrise run check  # the full linter StepLib CI runs
cd steps/<step-id> && bitrise run test   # live check, needs credentials
```

`bitrise run check` is the one that matters for the submission: it runs
yamllint, validates `step.yml` against
[the official JSON schema](https://raw.githubusercontent.com/bitrise-io/bitrise-json-schemas/main/step.schema.json),
and checks `step.yml` against the README. Things it rejects that are easy to get
wrong:

- `xamarin` is **no longer** a valid `project_type_tags` value.
- An input declaring `value_options` must have a **non-empty** default. If the
  input is genuinely optional, drop `value_options` and document the accepted
  values in its `summary` instead.
- `summary` must be a single line of 1-100 characters — use `summary: |-`, not
  `summary: |`, or the trailing newline fails the pattern.
- The `website` field must be a `github.com/<owner>/<repo>` URL, or
  `steps-readme-generator` crashes on it.

## 2. Bump the version

Set `BITRISE_STEP_VERSION` in `steps/<step-id>/bitrise.yml`. `scripts/publish.sh`
refuses to run if it disagrees with the version you pass on the command line.

Semver, and **breaking changes — including renaming or removing an input — only
in a major version.**

## 3. Regenerate the README

`README.md` is generated from `step.yml` plus `docs/examples.md` and
`docs/contributing.md` by Bitrise's own generator:

```bash
scripts/gen-readme.sh <step-id>    # or with no argument, for every Step
```

## 4. Mirror and tag

```bash
scripts/publish.sh <step-id> <version>          # dry run, prints what it would do
scripts/publish.sh <step-id> <version> --push   # mirror, then tag in the mirror
```

The tag lives in the **mirror**, because that is the repository the StepLib
resolves `--tag` against. `publish.sh` refuses to overwrite an existing tag.

> **Never move a tag that has already been shared.** The StepLib pins a commit
> SHA per version; re-tagging silently changes what published Workflows run. If
> something is wrong after sharing, bump the version.

## 5. Share to the StepLib

```bash
bitrise share start  -c "$MY_STEPLIB_REPO_FORK_GIT_URL"
bitrise share create --stepid <step-id> --tag <version> --git <mirror-url>
bitrise share audit  -c "$MY_STEPLIB_REPO_FORK_GIT_URL"
bitrise share finish
```

`share create` writes `steps/<step-id>/<version>/step.yml` into your fork, adding
the auto-generated `published_at` and `source` (git URL + commit) fields. Never
hand-write those.

## 6. Open the pull request

Against `bitrise-io/bitrise-steplib`, titled `<step-id>-<version>`.

The StepLib PR rules that catch people out:

- **One Step per pull request**, one file changed (plus an icon).
- Contributors can't see the StepLib CI results. First submissions often show
  failures the maintainers resolve — don't churn on it.
- If reviewers request changes you **cannot amend the PR**: close it, delete the
  share branch on the fork, fix the Step, tag a *new* version, and redo the flow
  in a new PR.

## 7. Icon

After the Step is merged, open a **separate** PR adding
`steps/<step-id>/assets/icon.svg`: 256×256 SVG, opaque background, 60 px margin.

## What lands on bitrise.io/integrations

There is nothing to submit separately — the integrations page is generated from
the StepLib repository once the pull request is merged. Each field comes from a
specific place:

| On the page | Comes from |
| --- | --- |
| URL `bitrise.io/integrations/steps/<step-id>` | the `steps/<step-id>/` directory name |
| Icon | `steps/<step-id>/assets/icon.svg` (the separate PR above) |
| Title, one-line blurb | `title`, `summary` in `step.yml` |
| Category badge | `type_tags` |
| "Github Source" link | `source_code_url` |
| Long body | `description` (Markdown, and it drives search ranking) |
| Official / Verified / Community badge | `maintainer:` in `steps/<step-id>/step-info.yml` |

`testingbot-upload-app` already has a page, so republishing under the same ID
updates it in place rather than creating a second one. The five new Steps get
their pages when their first version merges.

The Workflow Editor's step picker also filters by that maintainer field, which is
the practical reason to pursue Verified: it is the difference between appearing
under "Verified" next to BrowserStack and LambdaTest, or under "Community".

## Verified status

TestingBot owns the service, so these Steps qualify for the
[Verified](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/developing-your-own-bitrise-step/verified-steps)
badge. Applying requires submitting a Workflow Recipe showing the Step in use,
and accepting the maintainer SLA: first response within 5 business days,
resolution within 10 days (critical bug) / 15 (bug) / 20 (feature request).

Two consequences worth knowing before applying:

- **Never delete a mirror repository or its issue tracker.** Published
  `step.yml` files carry permanent links to them.
- Under the Abandoned Step policy, a Step left unmaintained can be deprecated or
  replaced by Bitrise. If we ever stop maintaining one, open an issue on
  `bitrise-io/bitrise-steplib` rather than deleting anything.
