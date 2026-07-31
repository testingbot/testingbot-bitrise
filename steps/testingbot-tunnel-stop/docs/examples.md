### Stop the tunnel at the end of the Workflow

With the defaults there is nothing to configure — it picks up
`$TESTINGBOT_TUNNEL_PID` from the start Step:

```yaml
- testingbot-tunnel:
    inputs:
    - testingbot_key: $TESTINGBOT_KEY
    - testingbot_secret: $TESTINGBOT_SECRET
- script:
    title: Run tests
    inputs:
    - content: npm test
- testingbot-tunnel-stop: {}
```

Because the Step is marked `is_always_run`, the tunnel is still closed when the
test Step fails.

### Always print the tunnel log

Useful when tests behave oddly but the tunnel didn't fail outright:

```yaml
- testingbot-tunnel-stop:
    inputs:
    - print_log: "true"
```

### Give a stubborn tunnel longer to exit

The Step asks the tunnel to stop, waits, then forces it:

```yaml
- testingbot-tunnel-stop:
    inputs:
    - shutdown_timeout: "60"
```
