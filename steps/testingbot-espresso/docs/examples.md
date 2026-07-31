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
