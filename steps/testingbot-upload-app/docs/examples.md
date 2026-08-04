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
