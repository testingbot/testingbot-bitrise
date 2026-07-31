### Run Maestro flows and publish the results

```yaml
- android-build: {}
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
- deploy-to-bitrise-io: {}
```

### The same flows on iOS

Nothing changes but the app — the platform follows from it:

```yaml
- xcode-archive: {}
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: iPhone 16
- deploy-to-bitrise-io: {}
```

### Cut wall-clock time with sharding

Splits the flows across parallel device sessions:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - shard_split: "4"
```

### Several flow directories

One per line:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 9
    - flows: |-
        .maestro/smoke
        .maestro/checkout
        .maestro/onboarding
```

### Tags, and environment variables for the flows

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - include_tags: smoke,critical
    - exclude_tags: slow
    - flow_env: |-
        API_URL=https://staging.example.com
        FEATURE_FLAG_NEW_CHECKOUT=true
```

### Collect screenshots and video for failures

The zip lands in `$BITRISE_DEPLOY_DIR`, so `Deploy to Bitrise.io` attaches it to
the build:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - download_artifacts: failed
- deploy-to-bitrise-io: {}
```

### Retry genuinely flaky flows

Only the flows that failed are re-run, and the last attempt decides the result.
Prefer fixing the flow — this will also hide a real regression:

```yaml
- testingbot-maestro:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - flows: .maestro
    - device: Pixel 9
    - retry: "1"
```
