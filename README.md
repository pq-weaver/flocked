# flocked

Simple process management for background tasks. Pure bash, zero dependencies.

```sh
flocked run myserver ./server.sh --port 8080
flocked ps
flocked kill myserver
```

## Philosophy

`flocked` does one thing: manage background processes. It starts them, tracks their status, captures their output, and kills them reliably—including all child processes.

Designed for AI agents and automation workflows where you need to:
- Start long-running processes and check back later
- Capture output to files for inspection
- Kill entire process trees cleanly

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/pq-weaver/flocked/main/install.sh | sh
```

Or manually:

```sh
curl -fsSL https://raw.githubusercontent.com/pq-weaver/flocked/main/flocked -o /usr/local/bin/flocked
chmod +x /usr/local/bin/flocked
```

## Usage

### Start a process

```sh
flocked run <name> <command...>
```

Starts the command in the background. Output is captured to a log file.

```sh
flocked run myserver ./server.sh --port 8080
# Started "myserver" (pid 12345)
```

If a process with that name is already running, `flocked` will error:

```sh
flocked run myserver ./other-server.sh
# "myserver" is already running (use -f to force)
```

Use `-f` to force-replace a running process:

```sh
flocked run -f myserver ./new-server.sh
```

Wait for a process to finish (default timeout: 60s). The timeout only releases the caller; it does **not** kill the process:

```sh
flocked run --wait --timeout 60 myjob ./job.sh
```

### List processes

```sh
flocked ps
```

```
NAME         STATUS       OUTPUT
myserver     running      /tmp/flocked-user/myserver/output.log
worker       exited 0     /tmp/flocked-user/worker/output.log
```

### Show process details

```sh
flocked ps <name>
```

```
name: myserver
status: running
pid: 12345
pgid: 12345
cmd: ./server.sh --port 8080
started: 2024-01-29 10:30:00
output: /tmp/flocked-user/myserver/output.log
```

### Kill a process

```sh
flocked kill <name>
```

Sends SIGTERM to the entire process tree. If processes don't exit within 5 seconds, sends SIGKILL.

```sh
flocked kill myserver
# Killing "myserver" (pid 12345, pgid 12345)...
# "myserver" terminated
```

### Read output

Output is captured to a plain text file. Use standard tools:

```sh
cat $FLOCKED_DIR/myserver/output.log
tail -f $FLOCKED_DIR/myserver/output.log
grep ERROR $FLOCKED_DIR/myserver/output.log
```

### Clean up

Remove stopped processes to free up state:

```sh
flocked clean <name>
```

Or remove all stopped processes at once:

```sh
flocked clean
# Cleaned 3 processes
```

### Wait for an existing process

Attach to a running (or already finished) managed process and wait for it to finish:

```sh
flocked wait <name>
```

Configure a timeout (in seconds). If the timeout expires, `flocked` returns a non-zero exit code but **does not** kill the running process:

```sh
flocked wait --timeout 60 myserver
```

On timeout, the command exits with code `124`.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLOCKED_DIR` | `/tmp/flocked-$USER` | State directory for process data |

## Example: AI Agent Workflow

An AI agent managing a development environment:

```sh
# Start the dev server
flocked run devserver npm run dev

# Check if it's running
flocked ps devserver

# Read recent output to check for errors
tail -20 $FLOCKED_DIR/devserver/output.log

# Restart with new configuration
flocked run -f devserver npm run dev -- --port 3001

# When done, clean up
flocked kill devserver
flocked clean devserver
```

## State Directory

Each managed process gets a directory:

```
$FLOCKED_DIR/
  └── <name>/
      ├── meta          # Process metadata (pid, pgid, cmd, started, exitcode)
      └── output.log    # Combined stdout/stderr
```

## License

MIT
