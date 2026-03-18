# Safer claw - Quick Start
<img width="206" height="375" alt="Safer Claw logo" src="./logo.png" />

**Requirements:**

Install these before continuing to the setup step below:
- Vagrant (used to setup the VM): https://developer.hashicorp.com/vagrant/install
- Virtualbox: https://www.virtualbox.org/wiki/Downloads
- Task (used as a thin wrapper for interacting with the VM): https://taskfile.dev/docs/installation

## 1. Setup (One Time)

Setup the virtual machine: installs dependencies, sets logging and starts the openclaw unit.
```bash
task create
```

The command will also guide you on what you need to do after that.

## 2. Add API Key for any model provider

```bash
task setup-models
```

## 3. Access

Run the following command to approve your machine login to the OpenClaw service.
```bash
task login
task approve-device
```
---

## Security Rules

**ALWAYS:**
- Use dedicated bot accounts for integrations
- Rotate API keys every 30 days
- Keep human approval enabled
- Monitor audit logs

**NEVER:**
- Store tokens in plaintext config
- Allow DMs/group chats as control channels
- Allow messages from unapproved senders
