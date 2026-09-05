# myDotfiles

Persönliche Konfigurationen für [Neovim](https://neovim.io/) mit
[AstroNvim v6](https://astronvim.com/), für [tmux](https://github.com/tmux/tmux),
für [Claude Code](https://claude.com/claude-code) und für
[Codex](https://developers.openai.com/codex/).

## Inhalt

Die Konfigurationen sind als [GNU Stow](https://www.gnu.org/software/stow/)-Pakete
organisiert. Jeder Ordner spiegelt dabei die Struktur relativ zu `$HOME` wider:

```text
.
├── tmux/
│   └── .tmux.conf                  # -> ~/.tmux.conf
├── nvim/
│   └── .config/
│       └── nvim/                  # -> ~/.config/nvim
│           ├── init.lua           # Einstiegspunkt der Neovim-Konfiguration
│           ├── lazy-lock.json     # festgeschriebene Plugin-Versionen
│           └── lua/
│               ├── lazy_setup.lua # AstroNvim- und lazy.nvim-Setup
│               ├── community.lua  # optionale AstroCommunity-Imports
│               ├── plugins/       # optionale Plugin-Anpassungen
│               └── polish.lua     # optionale abschließende Konfiguration
├── claude/
    └── .claude/
        ├── settings.json          # -> ~/.claude/settings.json
        └── statusline-command.sh  # -> ~/.claude/statusline-command.sh
├── codex/
│   └── .codex/
│       └── config.toml            # -> ~/.codex/config.toml
├── bin/
│   └── .local/
│       └── bin/
│           └── dotfiles-sync      # -> ~/.local/bin/dotfiles-sync
└── systemd/
    └── .config/
        └── systemd/
            └── user/
                ├── dotfiles-sync.service  # -> ~/.config/systemd/user/...
                └── dotfiles-sync.timer    # -> ~/.config/systemd/user/...
```

Das `claude`-Paket enthält bewusst nur die eigene Statusline-Konfiguration
(`settings.json`, `statusline-command.sh`) und keine der übrigen, teils
sensiblen oder lokalen Dateien unter `~/.claude` (z. B. `.credentials.json`,
`history.jsonl`, `sessions/`).

Das `codex`-Paket enthält ebenfalls nur die eigentliche Konfiguration
(`config.toml`). Zugangsdaten, Sitzungsverläufe, Datenbanken, Logs, Caches und
lokale Skills unter `~/.codex` bleiben bewusst außerhalb des Repositories.

Die Neovim-Konfiguration basiert auf AstroNvim v6. `lazy.nvim` wird beim ersten
Start automatisch installiert. Die Dateien unter `nvim/.config/nvim/lua/plugins/`
enthalten vorbereitete Beispiele, sind derzeit aber durch die jeweils erste
Zeile deaktiviert.

## Voraussetzungen

- Git
- [GNU Stow](https://www.gnu.org/software/stow/)
- systemd (für die automatische Aktualisierung beim Login, optional)
- Neovim in einer mit AstroNvim v6 kompatiblen Version
- tmux, falls die tmux-Konfiguration verwendet werden soll
- [Claude Code](https://claude.com/claude-code) mit `jq`, falls die
  Statusline-Konfiguration verwendet werden soll
- [Codex](https://developers.openai.com/codex/), falls die Codex-Konfiguration
  verwendet werden soll
- eine [Nerd Font](https://www.nerdfonts.com/) für die korrekte Darstellung
  der Neovim-Symbole (empfohlen)

## Installation

Vorhandene Konfigurationen sollten zunächst gesichert werden:

```sh
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.tmux.conf ~/.tmux.conf.bak
mv ~/.claude/settings.json ~/.claude/settings.json.bak
mv ~/.claude/statusline-command.sh ~/.claude/statusline-command.sh.bak
mv ~/.codex/config.toml ~/.codex/config.toml.bak
```

Nicht vorhandene Dateien oder Verzeichnisse können dabei einfach übersprungen
werden. Anschließend das Repository klonen und die Pakete mit Stow verlinken:

```sh
git clone https://github.com/Kzumelvin/myDotfiles.git ~/myDotfiles
cd ~/myDotfiles
stow -t ~ nvim tmux claude codex bin systemd
```

Danach übernimmt `dotfiles-sync` (siehe unten) alle weiteren Aktualisierungen.

Wichtig: Das Target (`-t ~`) muss immer explizit angegeben werden, da Stow
sonst standardmäßig das Elternverzeichnis des Repos als Ziel verwendet.

Neovim danach starten. Die Plugins werden beim ersten Start automatisch
heruntergeladen:

```sh
nvim
```

Eine bereits laufende tmux-Sitzung kann die Konfiguration mit folgendem Befehl
neu laden:

```sh
tmux source-file ~/.tmux.conf
```

## Automatische Aktualisierung (dotfiles-sync)

`bin/.local/bin/dotfiles-sync` aktualisiert das Repository per Git und spielt
anschließend alle Stow-Pakete ein. Die Pakete werden automatisch erkannt: jedes
Verzeichnis der obersten Ebene, das mindestens einen Dotfile-Eintrag enthält.

```sh
dotfiles-sync              # aktualisieren und stowen
dotfiles-sync --no-pull    # nur stowen, ohne git fetch/pull
dotfiles-sync --dry-run    # nur anzeigen, was passieren würde
dotfiles-sync --quiet      # nur Warnungen und Fehler ausgeben
```

Konfigurierbar über Umgebungsvariablen: `DOTFILES_DIR` (Default `~/myDotfiles`),
`DOTFILES_TARGET` (Default `$HOME`) und `DOTFILES_PACKAGES` (explizite
Paketliste statt automatischer Erkennung).

Das Skript arbeitet bewusst konservativ und überschreibt niemals lokale Arbeit:

- Bei lokalen Änderungen im Repository wird das Update übersprungen und nur
  gestowt.
- Aktualisiert wird ausschließlich per Fast-Forward. Divergierte Branches,
  ein fehlender Upstream oder ein detached HEAD führen zu einer Warnung.
- `git fetch` wird beim Systemstart bis zu dreimal versucht, da das Netzwerk
  zu diesem Zeitpunkt oft noch nicht bereit ist. Schlägt es fehl, wird
  trotzdem gestowt.
- Stow läuft je Paket einzeln (`--restow`). Ein Konflikt bricht die übrigen
  Pakete nicht ab, wird aber am Ende gemeldet (inkl. `notify-send`, sofern
  eine Desktop-Sitzung vorhanden ist) und führt zu Exit-Code 1.

### Start beim Login

Der User-Service `systemd/.config/systemd/user/dotfiles-sync.service` führt das
Skript einmal pro Login aus:

```sh
systemctl --user enable --now dotfiles-sync.service
```

Optional zusätzlich einmal täglich (verpasste Läufe werden nachgeholt):

```sh
systemctl --user enable --now dotfiles-sync.timer
```

Logs:

```sh
journalctl --user -u dotfiles-sync.service -n 50
```

Nach Änderungen an den Unit-Dateien ist ein `systemctl --user daemon-reload`
erforderlich.

## tmux-Tastenkürzel

Der tmux-Präfix wurde von `Ctrl-b` auf `Ctrl-x` geändert.

| Tastenkürzel | Aktion |
| --- | --- |
| `Ctrl-x`, `\|` | Fenster horizontal teilen |
| `Ctrl-x`, `-` | Fenster vertikal teilen |
| `Ctrl-x`, `r` | Konfiguration neu laden |
| `Alt` + Pfeiltaste | Zwischen Bereichen wechseln |
| `Ctrl-x`, `Alt-h/j/k/l` | Aktuellen Bereich in 5er-Schritten vergrößern oder verkleinern |

Zusätzlich ist die Mausunterstützung aktiviert.

## Claude-Code-Statusline

`claude/.claude/statusline-command.sh` zeigt in der Claude-Code-Statusline:

- aktuelles Verzeichnis (letzte 2 Pfadsegmente) und Git-Branch inkl. Status
  (`⇡`/`⇣` ahead/behind, `✗` geänderte, `?` unversionierte Dateien)
- 5-Stunden- und 7-Tage-Rate-Limit in Prozent (`rate_limits`, nur mit
  Pro-/Max-Abo verfügbar)
- Kontextfenster-Auslastung in Prozent
- den rechnerischen API-Gegenwert der Session als `API-Wert ~$X.XX` — **keine
  echten Kosten**, da diese im Pro-/Max-Abo bereits durch die Flatrate
  abgedeckt sind

## Anpassungen aktivieren

Die Beispielkonfigurationen in `nvim/.config/nvim/lua/community.lua`,
`nvim/.config/nvim/lua/plugins/*.lua` und `nvim/.config/nvim/lua/polish.lua`
beginnen mit einer vorzeitigen `return`-Anweisung. Zum Aktivieren einer Datei
muss diese erste Zeile entfernt werden. Die enthaltenen Beispiele sollten
vorher geprüft und auf den eigenen Bedarf reduziert werden.

Wichtige Stellen für Anpassungen:

- `nvim/.config/nvim/lua/lazy_setup.lua`: Leader-Tasten und grundlegende
  AstroNvim-Optionen
- `nvim/.config/nvim/lua/community.lua`: AstroCommunity-Pakete
- `nvim/.config/nvim/lua/plugins/`: LSP, Treesitter, Mason, Oberfläche und
  weitere Plugins
- `nvim/.config/nvim/lua/polish.lua`: freie Lua-Konfiguration nach dem Setup

Plugin-Aktualisierungen werden in Neovim mit `:Lazy update` durchgeführt. Die
resultierenden Versionen werden in `nvim/.config/nvim/lazy-lock.json`
gespeichert.

## Manuell installierte Mason-Pakete

Die folgenden Werkzeuge sind lokal über Mason installiert, werden von dieser
Konfiguration aber nicht automatisch eingerichtet und müssen nach einer
Neuinstallation daher erneut installiert werden:

- `docker-compose-language-service`
- `html-lsp`
- `jedi-language-server`
- `mdx-analyzer`
- `shfmt`
- `stylua`
- `tailwindcss-language-server`
- `ts-standard`
- `typescript-language-server`

Alle Pakete lassen sich in Neovim gemeinsam installieren:

```vim
:MasonInstall docker-compose-language-service html-lsp jedi-language-server mdx-analyzer shfmt stylua tailwindcss-language-server ts-standard typescript-language-server
```
