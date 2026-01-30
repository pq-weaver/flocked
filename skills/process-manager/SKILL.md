---
name: process-manager
description: Always use this skill for managing long-running processes such as webservers or watchers, and processes with potentially long output like linters or tests.
---

# Process Management with flocked

To manage processes, use the `flocked` utility.

## Commands

```sh
flocked run <name> <cmd...>     # start process
flocked run -f <name> <cmd...>  # force replace existing
flocked ps                      # list all
flocked ps <name>               # show details
flocked kill <name>             # kill process tree
```

## Output

Flocked processes have their output written to a file at `$FLOCKED_DIR/<name>/output.log` (If `$FLOCKED_DIR` is not set, it defaults to `/tmp/flocked-$USER/`)
You can also get the exact path to the output with `flocked ps [<name>]`.

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
rm -rf $FLOCKED_DIR/devserver
```
