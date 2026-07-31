### Test a staging environment with Appium

Start the tunnel, run the tests, stop the tunnel — the stop Step is configured to
run even if the tests fail:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
- script:
    title: Run Appium tests
    inputs:
    - content: |-
        #!/usr/bin/env bash
        set -eo pipefail
        npm test
- testingbot-tunnel-stop: {}
```

In your test capabilities, route the session through the tunnel:

```javascript
const capabilities = {
  platformName: 'Android',
  'appium:deviceName': 'Pixel 9',
  'appium:app': process.env.TESTINGBOT_APP_URL,
  'tb:options': {
    tunnelIdentifier: process.env.TESTINGBOT_TUNNEL_IDENTIFIER,
    build: `Bitrise #${process.env.BITRISE_BUILD_NUMBER}`,
  },
};
```

### Reach a server running on the build machine

```yaml
- script:
    title: Start the app under test
    inputs:
    - content: |-
        #!/usr/bin/env bash
        npm run start:ci &
        sleep 5
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
- script:
    title: Run tests against http://localhost:3000
    inputs:
    - content: npm test
- testingbot-tunnel-stop: {}
```

### Name the tunnel

The default already keeps concurrent Bitrise builds apart. Set it explicitly
when several tunnels run inside one build:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - tunnel_identifier: staging-$BITRISE_BUILD_NUMBER
    - ready_timeout: "180"
```

### Diagnose a tunnel that won't connect

The log is printed automatically when the tunnel fails to start. To see it on a
successful run too, raise the level and ask the stop Step to print it:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - log_level: debug
- testingbot-tunnel-stop:
    inputs:
    - print_log: "true"
```

### You may not need this Step

The Espresso, XCUITest and Maestro Steps open their own tunnel:

```yaml
- testingbot-espresso:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
    - device: Pixel 8
    - tunnel: "true"
```
