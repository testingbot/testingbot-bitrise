# (Android) Run Espresso tests on real devices with TestingBot

## Description

Run your Espresso suite on real Android devices in the [TestingBot](https://testingbot.com)
device cloud, and read the results on the Bitrise **Test Reports** tab.

The Step uploads the app and test APKs, runs the suite, streams progress into the
build log, downloads the JUnit report, and **fails the build when a test fails**
— so a broken test turns the build red rather than passing quietly.

## Prerequisites

1. A [TestingBot](https://testingbot.com) account. Copy your key and secret from
   the [member area](https://testingbot.com/members/user/api).
2. Add them to your Bitrise app as [Secrets](https://devcenter.bitrise.io/en/builds/env-vars-and-secrets/secrets.html)
   named `TESTINGBOT_KEY` and `TESTINGBOT_SECRET`. The Step reads those names by
   default, so it needs no credential inputs of its own.

## Instructions

1. Add an [Android Build for UI Testing](https://bitrise.io/integrations/steps/android-build-for-ui-testing)
   Step. It produces both APKs the run needs and exposes them as
   `$BITRISE_APK_PATH` and `$BITRISE_TEST_APK_PATH`. Set the input variables:
    - **Variant**: the variant to build, for example `debug`.
    - **Module**: the module to build, or leave it blank for the whole project.
2. Add a [TestingBot App Automate - Espresso](https://bitrise.io/integrations/steps/testingbot-espresso)
   Step. It picks up both APKs from the Step above, so it needs no inputs at all
   to get started. The ones worth knowing:
    - **Device**: a name, or a pattern such as `Pixel.*` or `*` to let TestingBot
      choose. Defaults to `*`.
    - **Fail the build when tests fail**: on by default. Turn it off to report
      the result through `$TESTINGBOT_TEST_STATUS` and keep the build green.
    - **Only these classes** / **Only these packages** / **Only these
      annotations**: narrow the run, for example to a smoke subset on pull
      requests.
3. Add a [Deploy to Bitrise.io](https://bitrise.io/integrations/steps/deploy-to-bitrise-io)
   Step. The Espresso Step has already written its JUnit report into
   `$BITRISE_TEST_RESULT_DIR`, and this Step is what publishes it to the
   [Test Reports add-on](https://devcenter.bitrise.io/en/testing/test-reports.html).

## bitrise.yml

```yaml
- android-build-for-ui-testing@0:
    inputs:
    - variant: $VARIANT
    - module: $MODULE
- testingbot-espresso@1: {}
- deploy-to-bitrise-io@2: {}
```

To run a subset on pull requests and the whole suite on `main`, give the Step a
filter instead:

```yaml
- testingbot-espresso@1:
    inputs:
    - device: Pixel 8
    - filter_annotation: com.example.SmokeTest
```

## Links

* https://testingbot.com/support/app-automate/espresso
* https://devcenter.bitrise.io/en/testing/test-reports.html
* https://github.com/testingbot/bitrise-step-testingbot-espresso
