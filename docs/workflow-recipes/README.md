# Workflow Recipes

Recipes are short, copy-paste `bitrise.yml` snippets that Bitrise hosts at
[bitrise-io/workflow-recipes](https://github.com/bitrise-io/workflow-recipes)
and surfaces in its docs. Submitting one is a **requirement of the Verified
Steps application**, not optional polish — see [RELEASING.md](../RELEASING.md).

They live here until the Steps they reference are merged into the StepLib,
because a recipe pointing at a Step nobody can install is not much use.

| Recipe | Chain |
| --- | --- |
| [android-espresso-tests-on-testingbot.md](android-espresso-tests-on-testingbot.md) | `android-build-for-ui-testing` → `testingbot-espresso` → `deploy-to-bitrise-io` |

## Submitting

Follow [`contribution/recipe-template.md`](https://github.com/bitrise-io/workflow-recipes/blob/main/contribution/recipe-template.md)
upstream — the headings here already match it. A submission is two files:

1. the recipe, at `recipes/<name>.md`
2. an entry in `recipes/recipes.yml`:

```yaml
- file: 'recipes/android-espresso-tests-on-testingbot.md'
  name: 'Run Espresso tests on real devices with TestingBot'
  platforms: ['android']
```

## Do not put the upload Step in front of a test Step

`testingbot-espresso`, `testingbot-xcuitest` and `testingbot-maestro` upload the
app themselves — the build log shows `Uploading Espresso App` — so adding
`testingbot-upload-app` before one of them uploads the binary twice and the
`tb://` identifier it exports is never read.

`testingbot-upload-app` is for the flows that genuinely need a `tb://`
identifier: Appium, or a test runner of your own. A recipe for that chain is
worth writing separately, and it is a different shape:

```yaml
- android-build@1: {}
- testingbot-upload-app@1: {}
- script@1:
    title: Run Appium tests
    inputs:
    - content: |-
        #!/usr/bin/env bash
        set -eo pipefail
        # $TESTINGBOT_APP_URL holds the tb:// identifier of the app just uploaded.
        npm test
- deploy-to-bitrise-io@2: {}
```
