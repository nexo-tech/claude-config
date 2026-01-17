---
name: smdctl-deploy
description: Deploy applications as systemd user services using smdctl. Use when the user asks to "deploy a service", "run as a systemd service", "create a background service", "start on boot", "daemonize", mentions "smdctl", or wants to run an application persistently in the background on Linux.
---

# smdctl Deploy Skill

Deploy applications as persistent systemd user services. Zero sudo required for ports >= 1024.

## Quick Start

1. Create `smdctl.yml` in project root
2. Run `smdctl run -f smdctl.yml`
3. Verify with `smdctl status <name>`

## Configuration File (smdctl.yml)

### Minimal Example

```yaml
name: myapp
command: /path/to/binary
```

### Full Configuration Reference

```yaml
# Required
name: myapp                    # Service name (alphanumeric, -, _)
command: /usr/bin/node         # Executable path

# Optional - Common
args:                          # Command arguments
  - server.js
  - --port
  - "3000"
description: My Application    # Service description
workdir: /opt/myapp           # Working directory (default: /)
environment:                   # Environment variables
  PORT: "3000"
  NODE_ENV: production
restart: always               # no | on-failure | always (default: always)

# Optional - Timeouts
timeout_start: 90             # Startup timeout seconds (default: 90)
timeout_stop: 30              # Stop timeout seconds (default: 30)

# Optional - Security (user mode)
private_tmp: true             # Isolate /tmp
no_new_privileges: true       # Prevent privilege escalation

# Optional - Resource Limits
limit_nofile: 65536           # File descriptor limit
tasks_max: 4096               # Max number of tasks

# Optional - Dependencies
after:                        # Start after these targets
  - network-online.target
wants:                        # Soft dependencies
  - network-online.target

# Optional - System Mode (avoid unless needed)
system_mode: false            # Force system mode (requires sudo)
user: appuser                 # Run as user (system mode only)
protect_system: full          # no | strict | full (system mode)
kill_mode: control-group      # control-group | process | mixed
```

## Service Examples

### Go Binary

```yaml
name: mygoapp
command: /opt/mygoapp/server
workdir: /opt/mygoapp
environment:
  PORT: "8080"
  GIN_MODE: release
restart: always
```

### Node.js

```yaml
name: nodeapi
command: /usr/bin/node
args: [server.js]
workdir: /home/user/projects/api
environment:
  NODE_ENV: production
  PORT: "3000"
restart: always
timeout_start: 60
```

### Python

```yaml
name: flaskapp
command: /home/user/.venv/bin/python
args: [-m, gunicorn, -b, "0.0.0.0:5000", app:app]
workdir: /home/user/projects/flask
environment:
  FLASK_ENV: production
restart: always
```

### Background Worker

```yaml
name: worker
command: /opt/worker/bin/worker
args: [--queue, default, --concurrency, "4"]
workdir: /opt/worker
environment:
  REDIS_URL: redis://localhost:6379
restart: always
timeout_stop: 60
kill_mode: mixed
```

## Deployment Workflow

### Deploy New Service

```bash
# 1. Create config
# Write smdctl.yml in project directory

# 2. Deploy and start
smdctl run -f smdctl.yml

# 3. Verify
smdctl status myapp
smdctl logs -f myapp
```

### Update Existing Service

```bash
# 1. Stop service
smdctl stop myapp

# 2. Update smdctl.yml or code

# 3. Remove and redeploy
smdctl rm myapp
smdctl run -f smdctl.yml
```

### Environment Variable Updates

```bash
# Interactive editor
smdctl env myapp
# Then restart
smdctl restart myapp
```

## Essential Commands

| Command | Description |
|---------|-------------|
| `smdctl run -f smdctl.yml` | Deploy from config |
| `smdctl ps` | List running services |
| `smdctl ps -a` | List all services |
| `smdctl status NAME` | Detailed status |
| `smdctl logs NAME` | View logs |
| `smdctl logs -f NAME` | Follow logs |
| `smdctl restart NAME` | Restart service |
| `smdctl stop NAME` | Stop service |
| `smdctl rm NAME` | Remove service |
| `smdctl inspect NAME` | Show config (YAML) |
| `smdctl explain -f smdctl.yml` | Dry-run preview |

## File Locations (User Mode)

- Service files: `~/.config/systemd/user/smdctl-{name}.service`
- Env files: `~/.config/smdctl/env/{name}.env`
- Log files: `~/.config/smdctl/logs/{name}.log`

## Troubleshooting

### Service fails to start

```bash
# 1. Check status
smdctl status myapp

# 2. View logs
smdctl logs -n 100 myapp

# 3. Inspect config
smdctl inspect myapp

# 4. Dry-run to preview
smdctl explain -f smdctl.yml
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Command not found | Use absolute path in `command` |
| Permission denied | Check file permissions, use user mode |
| Port already in use | Check with `ss -tlnp`, stop conflicting service |
| Service keeps restarting | Check logs, fix application errors |
| Env vars not loaded | Restart service after `smdctl env` changes |
