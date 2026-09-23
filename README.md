# dotfiles

Sanitized, secrets-free configs for zsh, ghostty, starship, opencode, git, vscode.

No emails, API keys, passwords, or tokens are committed. See `.gitignore`.

## Layout

- `zsh/` → `~/.zshrc`, `~/.zprofile`, `~/.zshenv`, `~/.profile`, `~/.zsh/*` (incl. `oc.zsh`, which provides `ocgo`)
- `config/ghostty/config` → `~/.config/ghostty/config`
- `config/starship.toml` → `~/.config/starship.toml`
- `config/opencode/opencode.json`, `cli.json` → `~/.config/opencode/`
- `config/git/ignore` → `~/.config/git/ignore`
- `git/.gitconfig` → `~/.gitconfig` (placeholder, no identity)
- `git/ignore-global` → `~/.gitignore`
- `vscode/settings.json`, `keybindings.json` → `~/Library/Application Support/Code/User/`
- `Brewfile` → `brew bundle`

## Never committed

`~/.zsh/secrets.zsh`, `~/.config/opencode/service.json`,
`~/.ssh/`, `~/.aws/`, `~/.codex/auth.json`, `~/.commandcode/`,
`~/.gemini/*oauth-token*`, `*.pem`, `*.key`, history/DB/logs.

## Install

```sh
./install.sh
# then set identity locally (not in repo):
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
brew bundle
```
