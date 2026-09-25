# mise-bootstrap-dotfiles

Declarative machine setup for my personal (Fedora Silverblue) and work (macOS)
workstations, built on [mise](https://mise.jdx.dev)'s `bootstrap` feature.
One repo, adopted as `~/.config/mise` describes packages,
tools, dotfiles, system files, services and secrets for both machines. No
secret ever lives in this repo — [fnox](https://fnox.jdx.dev) resolves them
from Bitwarden at apply time.

## Quick start

On a brand new machine:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nikokultalahti/mise-bootstrap-dotfiles/main/bootstrap.sh)
```

You'll be asked which profile this machine is (personal/work), then prompted
to log in to Bitwarden if needed. Everything else is automatic.

### What that script actually does

`bootstrap.sh` is used to handle a few chicken-and-egg problems on the initial bootstrap.
Here's what it does:

1. Installs `mise` itself (official installer) and activates it for the
   current shell.
2. Asks which profile to bootstrap and remembers it as `-E personal` or
   `-E work` for this run.
3. Pulls in `bitwarden` and `fnox` ad hoc via `mise exec` (not `mise use -g`,
   which would write `~/.config/mise/config.toml` itself and make the next
   step's `--adopt` refuse to touch that directory).
4. Configures the Bitwarden server (`vault.bitwarden.eu`), logs in and
   unlocks the vault, exporting `BW_SESSION` so fnox can use it.
5. Clones this repo into `~/.config/mise` with plain `git` over HTTPS (a
   no-op if it's already cloned). This has to happen over HTTPS and before
   fnox runs: fnox can't resolve anything until its config
   ([fnox.toml](fnox.toml)) exists on disk, and there's no SSH key yet
   either — that key is one of the things bootstrap is about to create.
6. Runs `fnox exec -- mise -E <profile> bootstrap --adopt <repo>` from
   inside that checkout.

After that first run, the SSH key exists, and a final hook
switches `~/.config/mise`'s `origin` remote from HTTPS to SSH so you can
push/pull immediately.

## Layout

| Path | Purpose |
|---|---|
| `bootstrap.sh` | One-time bootstrap entry point. |
| `config.toml` | Shared base: common `[tools]`, the GitHub SSH key/known_hosts, shared dotfiles/templates, the final hook. Loaded on every machine. |
| `config.personal.toml` | Personal (Fedora Silverblue) profile: Flatpak packages, systemd services/units, NextDNS config, personal SSH config, personal-only tools and hooks. Loaded with `-E personal`. |
| `config.work.toml` | Work (macOS) profile: Homebrew formulae/casks, work SSH config, work-only CLI tooling (k8s, Terraform, gcloud, etc). Loaded with `-E work`. |
| `fnox.toml` | Maps secret names to where fnox should fetch them from (Bitwarden vault item + field). No secret values, just references. |
| `dotfiles/` | Static files (`mode = "copy"`) and Tera templates (`mode = "template"`, `.tera` extension) applied via `[dotfiles]` in the config files. |
| `system_files/` | Plain files installed to root-owned system paths (e.g. `/etc/rpm-ostreed.conf`). |
| `scripts/` | Imperative shell scripts invoked from `[bootstrap.hooks.*]` for things that aren't declarative (Flathub setup, enabling a systemd user socket, etc). |
| `.gitignore` | Ignores `miserc.toml`, the machine-local file that persists which profile was chosen. |

## Secrets

Nothing sensitive is ever committed. `fnox.toml` only declares *where* a
secret named e.g. `GITHUB_SSH_KEY` lives (a Bitwarden item/field); the actual
value is fetched from Bitwarden vault at bootstrap time. `[bootstrap.secrets]` in
the config files gives those names to mise, and `{{ secret(name = "...") }}` in a templated
`bootstrap.files` entry is where a resolved value actually gets written
(e.g. `~/.ssh/id_ed25519`, `~/.ssh/config`).

Because fnox needs to actually run `bw`/talk to Bitwarden to resolve
anything, any `mise bootstrap` that touches one of these secret-backed files
needs to be wrapped in `fnox exec -- ...`, with `BW_SESSION` already set (see
[bootstrap.sh](bootstrap.sh)'s Bitwarden login/unlock block). A plain,
unwrapped `mise bootstrap` still works for everything else (tools, packages,
services, non-secret files) — it just can't touch the secret-backed ones.

## Profiles / environments

"Personal" and "work" are mise [config environments](https://mise.jdx.dev/configuration/environments.html)
(`-E personal` / `-E work`), which is how `config.personal.toml` /
`config.work.toml` get layered on top of `config.toml`. You don't need to
remember the flag after the first bootstrap: each profile file's
`[bootstrap.files]` writes `~/.config/mise/miserc.toml` with
`env = ["personal"]` (or `["work"]`), and mise loads that file early, before
anything else, on every future invocation. It's gitignored since it's a
statement about *this machine*, not something to share between them.

## Day-to-day workflow

`~/.config/mise` is a normal git working directory once adopted, so:

- **Add/change a tool:** edit the relevant `[tools]` block (`config.toml`
  for both machines, the profile file for one machine only), then
  `mise bootstrap` to install it. `mise use -g <tool>@version` also works,
  which edits `config.toml` file.
- **Add/change a dotfile:** drop the file under `dotfiles/` (or
  `system_files/` for root-owned system paths) and add a `[dotfiles]` entry
  — `mode = "copy"` for static files, `mode = "template"` (source ending in
  `.tera`) for ones that need `vars.*`, `mise_env`, `os()`, etc. Use
  `variants` when the target path differs by OS (see the VS Code/Zed
  entries). Re-run `mise bootstrap` to apply.
- **Change bootstrap config in general** (packages, services, hooks): edit
  the TOML, optionally `mise bootstrap plan` to preview, then
  `mise bootstrap` to converge. It's idempotent and non-transactional — a
  failure partway through (e.g. a secret that needs `fnox exec`) doesn't
  undo what already succeeded, so it's always safe to just fix the problem
  and re-run.
- **Pick up changes made on another machine:** `git pull` only updates the
  files on disk — it doesn't apply anything by itself. Follow it with
  `fnox exec -- mise bootstrap --adopt nikokultalahti/mise-bootstrap-dotfiles`
  (or a plain `mise bootstrap` if you know nothing secret-backed changed) to
  actually converge this machine.
- **Commit your changes** the same way you would in any git repo — this
  checkout has a real `origin` remote (SSH, after the first bootstrap) and
  pushes/pulls normally.
