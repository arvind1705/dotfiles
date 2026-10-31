# dotfiles

Sanitized, secrets-free configs for zsh, ghostty, starship, opencode, git, vscode.

No emails, API keys, passwords, or tokens are committed. See `.gitignore`.

This repo is an **archive** of the live files — nothing is symlinked or
auto-installed. Keep it in sync by copying changes here after you edit a config.

## Layout

- `zsh/` — zsh startup files and modules:
  - `.zshenv` — environment for every zsh process
  - `.zprofile` — login-shell PATH (runs after macOS `path_helper`)
  - `.zshrc` — interactive shell setup
  - `.profile` — POSIX fallback for `sh` (bash uses `~/.bash_profile`)
  - `.zsh/path.zsh` — single source of PATH entries
  - `.zsh/integrations.zsh`, `runtimes.zsh`, `functions.zsh`, `oc.zsh` (provides `ocgo`), `aliases.zsh`
- `config/ghostty/config`
- `config/starship.toml`
- `config/opencode/opencode.jsonc`, `cli.json`
- `config/git/ignore`
- `git/.gitconfig` (placeholder, no identity)
- `git/ignore-global`
- `vscode/settings.json`, `keybindings.json`
- `Brewfile` — `brew bundle`

## Syncing a change

```sh
cp ~/.config/opencode/opencode.jsonc config/opencode/
git add -A && git commit -m "chore: sync <what changed>"
```

## Restoring on a new machine

Copy the files back to their live paths by hand, e.g.:

```sh
cp config/opencode/opencode.jsonc ~/.config/opencode/
cp zsh/.zshenv zsh/.zprofile zsh/.zshrc zsh/.profile ~/
mkdir -p ~/.zsh && cp zsh/.zsh/*.zsh ~/.zsh/
cp zsh/.zsh/secrets.zsh.example ~/.zsh/   # then create secrets.zsh from it
brew bundle
git config --global user.name "Your Name"   # identity stays local
```

## Never committed

`~/.zsh/secrets.zsh`, `~/.config/opencode/service.json`,
`~/.ssh/`, `~/.aws/`, `~/.codex/auth.json`, `~/.commandcode/`,
`~/.gemini/*oauth-token*`, `*.pem`, `*.key`, history/DB/logs.
