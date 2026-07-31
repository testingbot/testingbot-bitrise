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
