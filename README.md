# ctrun

`ctrun` is a lightweight wrapper that makes running CLI tools inside Docker
containers feel native on macOS. Each tool uses **its own Docker image**, but
executes with:

- Your **UID:GID** (correct file permissions)
- Your **$HOME**, **/tmp**, and **current directory** mounted automatically
- Your terminal settings and environment
- An **overridden ENTRYPOINT** so *your command* always runs

No long-lived VM, no persistent base container — just clean, Lima-like behavior
using plain Docker.

---

## Features

- 🐳 **Ephemeral containers** (`--rm`), one per command  
- 👤 **Runs as your user**, so created files belong to you  
- 📁 **Automatic mounts**:  
  - `$HOME → $HOME`  
  - `/tmp → /tmp`  
  - `$PWD → $PWD`
- 🔧 **ENTRYPOINT always overridden**  
- 🖥️ **TTY passthrough** for interactive sessions  
- 🌐 Environment variables like `TERM`, `LANG` preserved  
- 🔗 Simple per-tool wrappers

---

## Usage

Run any image:

```bash
ctrun ubuntu:22.04 bash
````

Run a tool command from an image:

```bash
ctrun ghcr.io/my-org/tool:latest mytool --help
```

If you specify no command, `bash` is launched:

```bash
ctrun ghcr.io/my-org/tool:latest
```

---

## Per-tool wrapper example

Create a native-feeling command:

```bash
# ~/bin/brain-cli
#!/usr/bin/env bash
exec ctrun ghcr.io/my-org/brain-cli:latest "$@"
```

Now you can run:

```bash
brain-cli run experiment.yaml
```

---

## Environment variable passthrough

You can allow additional variables via:

```bash
export DOCKER_WRAPPER_ENV_WHITELIST="SSH_AUTH_SOCK GIT_AUTHOR_NAME"
```

---

## Install

1. Copy `ctrun` into your `$PATH` (e.g. `~/bin/ctrun`) or symlink it 
2. Make executable:

```bash
chmod +x ~/bin/ctrun
```

That's it.

---

## License

MIT. Do whatever you want. Ack would be nice.
