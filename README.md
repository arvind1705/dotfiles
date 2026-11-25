# Dotfiles

Personal shell, editor and tool configuration (`home/`: zsh, starship, ghostty, git, vscode, Brewfile) for the MacBook Air, the Mac mini and the devbox.

Machine setup, Docker stacks, tailnet DNS, the reverse proxy and the fleet portal live in a separate repository: [arvind1705/fleet](https://github.com/arvind1705/fleet).

---

## Quickstart (New Machine Replication)

To install the dotfiles on a machine:

```bash
git clone https://github.com/arvind1705/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh --dotfiles
```

Preview local changes with `./install.sh --dotfiles --dry-run`. Applying the dotfiles saves replaced files under `~/.dotfiles-backup.*` and leaves symlink destinations alone. Review differences before applying, especially editor settings. Use `~/.zsh/env.local.zsh` for environment overrides in all Zsh sessions, `~/.zsh/local.zsh` for interactive-only settings, and `~/.zsh/secrets.zsh` for private interactive credentials. The installer leaves all three untouched.

Conda initializes on first use (`conda activate <env>`). The installer does not overwrite `~/.condarc`; if you use Conda's own startup hook, set `auto_activate_base: false` to avoid activating base on startup. Use `CONDA_ROOT` in your local environment override if Miniconda is not at `~/miniconda3`.

The `encrypt` and `decrypt` shell helpers prompt for a passphrase. Previously encrypted files still need their original passphrase; re-encrypt anything that used the old shared default.

Run `bash scripts/validate.sh` to check shell syntax.

---

## Repository Layout

```
.
├── install.sh          # ./install.sh --dotfiles [--dry-run]
├── scripts/validate.sh # Shell syntax checks
└── home/
    ├── zsh/            # .zshenv, .zprofile, .zshrc, modules in .zsh/
    ├── bin/dev         # Development environment CLI
    ├── config/         # starship, ghostty, opencode, git ignore
    ├── git/            # git config
    ├── vscode/         # settings.json, keybindings.json
    └── Brewfile        # Homebrew bundle
```

---

## Secrets & Security Policy

- **Zero Secrets in Git**: No API keys, passwords, database dumps, or private keys are ever committed.
- Private files (`~/.zsh/secrets.zsh`, `env.local.zsh`, `local.zsh`) are excluded by `.gitignore`.
