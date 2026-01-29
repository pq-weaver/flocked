Let's create a simple utility script for process management. The script will be named `flocked`.
It should be written in pure bash, without any dependencies, and should be able to run on any POSIX-compliant system.

It should allow running arbitrary commands, check their status and reliably kill them with all their child processes.

Output of each command should be written to a file, so it can be grepped, tailed and otherwise read by an AI agent.

The directory where the script will hold it's state should be configurable, ideally defaulting to some temporary directory.

Provide a README.md for the script, and a simple installation script that can be used in the `curl ... | sh` format. (The code will be later pushed to github, at `pq-weaver/flocked`).

The whole codebase (which will be mostly just the script and the README) should be a museum piece of clean code. It should honor the unix philosophy of doing one thing and doing it well. It should be well known for it's simplicity and elegance.
