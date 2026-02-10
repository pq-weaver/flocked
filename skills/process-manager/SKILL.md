---
name: process-manager
description: Always use this skill for managing long-running processes such as webservers or watchers, and processes with potentially long output like linters or tests.
---

# Process Management with flocked

Use `flocked` to run, inspect, wait, and kill background processes.

## Commands

```sh
flocked run <name> <cmd...>                      # start process
flocked run -f <name> <cmd...>                   # force replace
flocked run --wait [--timeout <seconds>] <name> <cmd...>
flocked wait [--timeout <seconds>] <name>        # attach+wait (timeout doesn't kill)
flocked ps                      # list all
flocked ps <name>               # show details
flocked kill <name>             # kill process tree
flocked clean [name]            # remove stopped process(es)
```

## Output

Output: `$FLOCKED_DIR/<name>/output.log` (default `FLOCKED_DIR=/tmp/flocked-$USER`). Path also shown by `flocked ps [<name>]`.

You can use all your usual tools to work with the output file, such as Grep, Read file, or bash tools:

```sh
cat $FLOCKED_DIR/<name>/output.log
tail -20 $FLOCKED_DIR/<name>/output.log
```

## Patterns

Start server, verify running:

```sh
flocked run devserver npm run dev
flocked ps devserver
tail -20 $FLOCKED_DIR/devserver/output.log
```

Cleanup after done:

```sh
flocked kill devserver
flocked clean devserver
```
