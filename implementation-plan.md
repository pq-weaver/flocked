# Implementation Plan: `flocked`

A pure-bash process management utility that runs commands in the background, tracks their status, captures output to files, and reliably kills process trees.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Process identification | User-provided names (`flocked run myserver ./server.sh`) |
| Output format | Single `output.log` file (combined stdout/stderr) |
| Run behavior | Always background |
| Cleanup | Auto-replace exited processes; error if running (use `-f` to force) |

## State Directory Structure

```
$FLOCKED_DIR/                    # Default: /tmp/flocked-$USER
  └── <name>/
      ├── meta                   # Metadata file (key=value format)
      └── output.log             # Combined stdout/stderr
```

The `meta` file contains:
```
pid=12345
pgid=12345
cmd=./server.sh --port 8080
started=1706544000
exitcode=0                       # Added when process exits
```

## Command Interface

```
flocked run [-f] <name> <command...>  # Start a background process
flocked ps [name]                     # List all processes, or show detail for one
flocked kill <name>                   # Kill process and all children
```

### `run` cleanup behavior

| State | Behavior |
|-------|----------|
| Name doesn't exist | Create and start |
| Name exists, process exited | Clean up old files, start fresh |
| Name exists, process running | Error: `"myserver" is already running (use -f to force)` |
| Name exists, running, `-f` flag | Kill old process, clean up, start fresh |

Output of `flocked ps` (no args):
```
NAME      STATUS      OUTPUT
myserver  running     /tmp/flocked-user/myserver/output.log
worker    exited 0    /tmp/flocked-user/worker/output.log
```

Output of `flocked ps myserver` (with name):
```
name: myserver
status: running
pid: 12345
pgid: 12345
cmd: ./server.sh --port 8080
started: 2024-01-29 10:30:00
output: /tmp/flocked-user/myserver/output.log
```

Manual cleanup (if needed): `rm -rf $FLOCKED_DIR/<name>`

---

## Phase 1: Core Script + Run Command

Create the script skeleton and implement the `run` command with process group isolation.

### Relevant Context

- New file: `flocked` (the main script)
- Process groups: Use `setsid` to start processes in a new session, giving us a PGID we can use later to kill the entire tree
- POSIX consideration: `setsid` is POSIX but not always available; fallback to `(set -m; cmd)` for job control

### Implementation Steps

- [x] Create `flocked` script with shebang and usage function
- [x] Implement argument parsing with subcommand dispatch
- [x] Implement `_init_dir()` to create/validate state directory
- [x] Implement `cmd_run()`:
  - Parse `-f` flag if present
  - Validate name (alphanumeric + dash/underscore only)
  - Handle existing process:
    - If name exists and process is running:
      - Without `-f`: error with message `"<name>" is already running (use -f to force)`
      - With `-f`: kill the process (reuse kill logic)
    - If name exists and process exited: clean up old directory
  - Create process directory
  - Start process with `setsid` in background, redirecting stdout+stderr to `output.log`
  - Write `meta` file with pid, pgid, cmd, started

### Implementation Notes

- On macOS, `setsid` is not available. The script uses perl's POSIX::setsid() as a fallback to create a new session/process group.
- All automated verification tests pass (19/19).

### Verification

1. Run: `./flocked run test1 sleep 60`
2. Check directory exists: `ls $FLOCKED_DIR/test1/`
3. Verify files: `meta`, `output.log`
4. Verify meta contains: pid, pgid, cmd, started
5. Verify process running: `ps -p $(grep ^pid= $FLOCKED_DIR/test1/meta | cut -d= -f2)`
6. Run: `./flocked run test2 sh -c 'echo hello; echo err >&2'`
7. Wait 1 second, check `output.log` contains both "hello" and "err"
8. Test conflict error: `./flocked run test1 sleep 30` → should error with "-f to force" message
9. Test force replace: `./flocked run -f test1 sleep 30` → should kill old, start new

---

## Phase 2: The `ps` Command

Implement the `ps` command to inspect process state.

### Relevant Context

- File: `flocked`
- Status detection: Check if PID exists in `/proc/$pid` or via `kill -0 $pid`
- Exit code capture: Use a wrapper that appends exit code to `meta` when process exits

### Implementation Steps

- [x] Modify `cmd_run()` to use a wrapper script that appends exitcode to `meta` on completion
- [x] Implement `cmd_ps()`:
  - If no name provided: list all processes (name, status, output path)
  - If name provided: show detailed info (name, status, pid, pgid, cmd, started, output path)
  - Status logic:
    - If `exitcode` exists in meta: "exited N"
    - Else if PID is alive: "running"
    - Else: "dead" (process died without writing exitcode - shouldn't happen)

### Implementation Notes

- Fixed race condition: meta file is now written immediately after backgrounding the process (before the process can complete), so the wrapper can safely append `exitcode=N`.
- Added helper functions: `_get_status()` for status detection, `_format_time()` for timestamp formatting.
- All automated tests pass.

### Verification

1. Start a short-lived process: `./flocked run short sh -c 'echo done; exit 42'`
2. Wait 1 second
3. Run: `./flocked ps short` → should show "exited 42" and output path
4. Start a long-lived process: `./flocked run long sleep 300`
5. Run: `./flocked ps long` → should show "running" and output path
6. Run: `./flocked ps` → should list both `short` and `long` with paths

---

## Phase 3: The `kill` Command

Implement reliable process tree termination.

### Relevant Context

- File: `flocked`
- Process group kill: `kill -TERM -$PGID` sends SIGTERM to entire process group
- Graceful then forced: SIGTERM first, wait briefly, then SIGKILL if still alive

### Implementation Steps

- [ ] Implement `cmd_kill()`:
  - Read PGID from `meta` file
  - Send SIGTERM to process group: `kill -TERM -$PGID`
  - Wait up to 5 seconds for process to exit
  - If still alive, send SIGKILL: `kill -KILL -$PGID`
  - Verify process is dead

### Verification

1. Start a process with children:
   ```sh
   ./flocked run parent sh -c 'sleep 1000 & sleep 1000 & wait'
   ```
2. Verify children exist: `pgrep -P $(grep ^pid= $FLOCKED_DIR/parent/meta | cut -d= -f2)`
3. Run: `./flocked kill parent`
4. Verify parent dead: `./flocked ps parent` → should show exited/killed
5. Verify children dead: `pgrep -g $(grep ^pgid= $FLOCKED_DIR/parent/meta | cut -d= -f2)` → should return nothing
6. Manual cleanup: `rm -rf $FLOCKED_DIR/parent`
7. Verify removed: `ls $FLOCKED_DIR/parent` → should fail

---

## Phase 4: Documentation and Installation

Create README and installation script for `curl | sh` usage.

### Relevant Context

- New file: `README.md`
- New file: `install.sh`
- GitHub repo will be: `pq-weaver/flocked`
- Installation target: `/usr/local/bin/flocked` or `~/.local/bin/flocked`

### Implementation Steps

- [ ] Create `README.md`:
  - Project description and philosophy
  - Installation instructions (curl | sh)
  - Manual installation
  - Usage examples (`run`, `run -f`, `ps`, `kill`)
  - Environment variables (`FLOCKED_DIR`)
  - Example AI agent workflow
- [ ] Create `install.sh`:
  - Detect if user has write access to `/usr/local/bin`
  - If not, use `~/.local/bin` and warn about PATH
  - Download `flocked` from GitHub raw URL
  - Make executable
  - Print success message with usage hint
- [ ] Final polish:
  - Add `--help` / `-h` flag support
  - Add `--version` / `-v` flag
  - Ensure all error messages are clear and actionable

### Verification

1. Run: `./flocked --help` → should show usage
2. Run: `./flocked --version` → should show version
3. Test install script locally: `sh install.sh`
4. Verify installed: `which flocked`
5. Run full workflow:
   ```sh
   flocked run demo sh -c 'for i in 1 2 3; do echo $i; sleep 1; done'
   flocked ps
   flocked ps demo
   sleep 4
   flocked ps demo
   cat $FLOCKED_DIR/demo/output.log
   rm -rf $FLOCKED_DIR/demo
   ```

---

## Summary

| Phase | Deliverable | Key Files |
|-------|-------------|-----------|
| 1 | Working `run` command with process isolation | `flocked` |
| 2 | `ps` command (list + status + output paths) | `flocked` |
| 3 | `kill` command (process tree termination) | `flocked` |
| 4 | Documentation and installation | `README.md`, `install.sh` |
