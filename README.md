# dotfiles

Sanitized, secrets-free configs for zsh, ghostty, starship, opencode, git, vscode.

No emails, API keys, passwords, or tokens are committed. See `.gitignore`.

This repo is an **archive** of the live files — nothing is symlinked or
auto-installed. Keep it in sync by copying changes here after you edit a config.

## Layout

- `zsh/` — `.zshrc`, `.zprofile`, `.zshenv`, `.profile`, `.zsh/*` (incl. `oc.zsh`, which provides `ocgo`)
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
cp zsh/.zshrc ~/.zshrc
brew bundle
git config --global user.name "Your Name"   # identity stays local
```

## Never committed

`~/.zsh/secrets.zsh`, `~/.config/opencode/service.json`,
`~/.ssh/`, `~/.aws/`, `~/.codex/auth.json`, `~/.commandcode/`,
`~/.gemini/*oauth-token*`, `*.pem`, `*.key`, history/DB/logs.
