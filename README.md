# myDotfiles

Persönliche Konfigurationen für [Neovim](https://neovim.io/) mit
[AstroNvim v6](https://astronvim.com/) und für [tmux](https://github.com/tmux/tmux).

## Inhalt

Die Konfigurationen sind als [GNU Stow](https://www.gnu.org/software/stow/)-Pakete
organisiert. Jeder Ordner spiegelt dabei die Struktur relativ zu `$HOME` wider:

```text
.
├── tmux/
│   └── .tmux.conf                  # -> ~/.tmux.conf
└── nvim/
    └── .config/
        └── nvim/                  # -> ~/.config/nvim
            ├── init.lua           # Einstiegspunkt der Neovim-Konfiguration
            ├── lazy-lock.json     # festgeschriebene Plugin-Versionen
            └── lua/
                ├── lazy_setup.lua # AstroNvim- und lazy.nvim-Setup
                ├── community.lua  # optionale AstroCommunity-Imports
                ├── plugins/       # optionale Plugin-Anpassungen
                └── polish.lua     # optionale abschließende Konfiguration
```

Die Neovim-Konfiguration basiert auf AstroNvim v6. `lazy.nvim` wird beim ersten
Start automatisch installiert. Die Dateien unter `nvim/.config/nvim/lua/plugins/`
enthalten vorbereitete Beispiele, sind derzeit aber durch die jeweils erste
Zeile deaktiviert.

## Voraussetzungen

- Git
- [GNU Stow](https://www.gnu.org/software/stow/)
- Neovim in einer mit AstroNvim v6 kompatiblen Version
- tmux, falls die tmux-Konfiguration verwendet werden soll
- eine [Nerd Font](https://www.nerdfonts.com/) für die korrekte Darstellung
  der Neovim-Symbole (empfohlen)

## Installation

Vorhandene Konfigurationen sollten zunächst gesichert werden:

```sh
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.tmux.conf ~/.tmux.conf.bak
```

Nicht vorhandene Dateien oder Verzeichnisse können dabei einfach übersprungen
werden. Anschließend das Repository klonen und die Pakete mit Stow verlinken:

```sh
git clone https://github.com/Kzumelvin/myDotfiles.git ~/Projects/myDotfiles
cd ~/Projects/myDotfiles
stow -t ~ nvim tmux
```

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
