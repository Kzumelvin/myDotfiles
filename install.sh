#!/usr/bin/env bash
#
# install.sh - richtet die Dotfiles auf einem neuen (oder bestehenden) System ein.
#
# Führt alle Schritte aus der README aus: Abhängigkeiten installieren,
# Repository klonen, vorhandene Konfigurationen sichern, Pakete per GNU Stow
# verlinken, systemd-Units aktivieren, Neovim-Plugins und Mason-Pakete
# installieren und tmux neu laden. Das Skript ist idempotent und kann beliebig
# oft erneut ausgeführt werden.
#
# Aufruf:
#   ./install.sh                     # alles einrichten
#   ./install.sh --dry-run           # nur anzeigen, was passieren würde
#   ./install.sh --skip font,mason   # einzelne Schritte überspringen
#   ./install.sh --only link         # nur bestimmte Schritte ausführen
#   ./install.sh --timer             # zusätzlich den täglichen systemd-Timer aktivieren
#
# Ohne lokalen Klon:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Kzumelvin/myDotfiles/main/install.sh)
#
# Schritte (in dieser Reihenfolge):
#   deps     git, stow, tmux, jq, curl, unzip, Node.js/npm, Python
#   nvim     Neovim installieren bzw. auf NVIM_MIN_VERSION aktualisieren
#   claude   Claude Code installieren (falls nicht vorhanden)
#   codex    Codex installieren (falls nicht vorhanden)
#   herdr    herdr installieren (falls nicht vorhanden)
#   font     JetBrainsMono Nerd Font installieren (falls keine Nerd Font vorhanden)
#   repo     Repository klonen bzw. per Fast-Forward aktualisieren
#   link     vorhandene Dateien sichern und alle Pakete stowen (via dotfiles-sync)
#   systemd  dotfiles-sync.service (und optional .timer) aktivieren (nur Linux)
#   plugins  Neovim-Plugins headless installieren
#   mason    Mason-Pakete aus der README installieren
#   tmux     laufende tmux-Sitzung neu laden
#
# Umgebungsvariablen:
#   DOTFILES_DIR      Pfad zum Repository (Default: dieser Klon bzw. ~/myDotfiles)
#   DOTFILES_REPO     Git-URL (Default: https://github.com/Kzumelvin/myDotfiles.git)
#   DOTFILES_TARGET   Stow-Target (Default: $HOME)
#   NVIM_MIN_VERSION  minimal benötigte Neovim-Version (Default: 0.11.0)

set -o pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/Kzumelvin/myDotfiles.git}"
DOTFILES_TARGET="${DOTFILES_TARGET:-$HOME}"
NVIM_MIN_VERSION="${NVIM_MIN_VERSION:-0.11.0}"
DEFAULT_DIR="$HOME/myDotfiles"

# Verzeichnisse, die Stow als Ganzes verlinken darf. Alle anderen Verzeichnisse
# werden vorab real angelegt, damit Programme (Claude Code, Codex, systemctl,
# pip, ...) ihre lokalen Dateien nicht versehentlich ins Repository schreiben.
FOLD_DIRS=".config/nvim"

ALL_STEPS="deps nvim claude codex herdr font repo link systemd plugins mason tmux"

dry_run=0
timer=0
only=""
skip=""

while (($#)); do
  case "$1" in
    --dry-run|-n) dry_run=1 ;;
    --timer) timer=1 ;;
    --only) only="${2//,/ }"; shift ;;
    --only=*) only="${1#*=}"; only="${only//,/ }" ;;
    --skip) skip="${2//,/ }"; shift ;;
    --skip=*) skip="${1#*=}"; skip="${skip//,/ }" ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) printf 'install.sh: unbekannte Option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

for s in $only $skip; do
  [[ " $ALL_STEPS " == *" $s "* ]] || { printf 'install.sh: unbekannter Schritt: %s\n' "$s" >&2; exit 2; }
done

if [[ -t 1 ]]; then
  c_bold=$'\033[1m' c_blue=$'\033[34m' c_yellow=$'\033[33m' c_red=$'\033[31m' c_green=$'\033[32m' c_off=$'\033[0m'
else
  c_bold="" c_blue="" c_yellow="" c_red="" c_green="" c_off=""
fi

step() { printf '\n%s==> %s%s\n' "$c_bold$c_blue" "$*" "$c_off"; }
log()  { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$c_green" "$c_off" "$*"; }
warn() { printf '    %sWARN:%s %s\n' "$c_yellow" "$c_off" "$*" >&2; warnings=$((warnings + 1)); }
err()  { printf '    %sFEHLER:%s %s\n' "$c_red" "$c_off" "$*" >&2; }
die()  { err "$*"; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

warnings=0

# Führt einen Befehl aus bzw. zeigt ihn im Dry-Run nur an.
run() {
  if ((dry_run)); then
    printf '    [dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

wants() {
  local s="$1"
  [[ " $skip " == *" $s "* ]] && return 1
  [[ -z "$only" || " $only " == *" $s "* ]]
}

# Löst einen Pfad inkl. aller Symlinks auf (Perl ist als Stow-Abhängigkeit vorhanden).
resolve() { perl -MCwd -e 'my $p = Cwd::abs_path($ARGV[0]); print $p if defined $p' "$1" 2>/dev/null; }

# version_ge 0.11.2 0.11.0 -> wahr
version_ge() {
  local IFS=. i
  local -a a b
  read -r -a a <<<"$1"
  read -r -a b <<<"$2"
  for i in 0 1 2; do
    ((${a[i]:-0} > ${b[i]:-0})) && return 0
    ((${a[i]:-0} < ${b[i]:-0})) && return 1
  done
  return 0
}

# --- System erkennen ----------------------------------------------------------

os="$(uname -s)"
arch="$(uname -m)"
pm=""
case "$os" in
  Darwin) pm="brew" ;;
  Linux)
    for p in apt-get dnf pacman zypper; do
      has "$p" && { pm="$p"; break; }
    done
    ;;
  *) die "Nicht unterstütztes Betriebssystem: $os" ;;
esac

sudo=""
if [[ "$os" == Linux && "$(id -u)" != 0 ]]; then
  has sudo && sudo="sudo"
fi

orig_path="$PATH"
export PATH="$HOME/.local/bin:$PATH"
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

pkg_install() {
  (($#)) || return 0
  case "$pm" in
    brew) run brew install "$@" ;;
    apt-get) run $sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null ;;
    dnf) run $sudo dnf install -y "$@" ;;
    pacman) run $sudo pacman -S --needed --noconfirm "$@" ;;
    zypper) run $sudo zypper --non-interactive install "$@" ;;
    *) return 1 ;;
  esac
}

# Installiert alle Pakete gemeinsam; scheitert das, einzeln, damit ein fehlendes
# Paket (anderer Name je Distribution) nicht alle anderen blockiert.
pkg_install_each() {
  pkg_install "$@" && return 0
  local p rc=0
  for p in "$@"; do
    pkg_install "$p" || { warn "Paket '$p' konnte nicht installiert werden."; rc=1; }
  done
  return "$rc"
}

printf '%sDotfiles-Installation%s (%s/%s, Paketmanager: %s)%s\n' \
  "$c_bold" "$c_off" "$os" "$arch" "${pm:-keiner}" "$( ((dry_run)) && printf ' [dry-run]')"

# --- deps ---------------------------------------------------------------------

if wants deps; then
  step "Abhängigkeiten"

  if [[ "$pm" == brew ]] && ! has brew; then
    log "Homebrew fehlt - wird installiert."
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
      die "Homebrew-Installation fehlgeschlagen."
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
  fi

  # Befehl -> Paketname je Paketmanager
  missing=()
  need() {
    local cmd="$1" brew_pkg="$2" apt_pkg="$3" other_pkg="$4"
    has "$cmd" && return 0
    case "$pm" in
      brew) missing+=("$brew_pkg") ;;
      apt-get) missing+=("$apt_pkg") ;;
      pacman) [[ "$other_pkg" == python3 ]] && other_pkg=python; missing+=("$other_pkg") ;;
      *) missing+=("$other_pkg") ;;
    esac
  }
  need git     git     git      git
  need stow    stow    stow     stow
  need tmux    tmux    tmux     tmux
  need jq      jq      jq       jq
  need curl    curl    curl     curl
  need unzip   unzip   unzip    unzip
  need npm     node    npm      npm      # für diverse Mason-Pakete und Codex
  need python3 python  python3  python3  # für jedi-language-server (Mason)
  [[ "$os" == Linux ]] && need fc-cache "" fontconfig fontconfig

  if [[ "$pm" == apt-get ]]; then
    # Mason legt für Python-Pakete ein venv an; Debian/Ubuntu liefern das separat aus.
    if ! has python3 || ! python3 -c 'import ensurepip' >/dev/null 2>&1; then missing+=("python3-venv"); fi
  fi

  if ((${#missing[@]})); then
    [[ -n "$pm" ]] || die "Kein unterstützter Paketmanager gefunden. Bitte manuell installieren: ${missing[*]}"
    log "Installiere: ${missing[*]}"
    [[ "$pm" == apt-get ]] && run $sudo apt-get update -qq
    pkg_install_each "${missing[@]}"
  else
    ok "alle Abhängigkeiten vorhanden"
  fi
fi

((dry_run)) || has git || die "'git' fehlt."
((dry_run)) || has stow || die "'stow' fehlt."

# --- nvim ---------------------------------------------------------------------

nvim_version() { nvim --version 2>/dev/null | awk 'NR==1 { sub(/^NVIM v/, ""); sub(/-.*/, ""); print }'; }

if wants nvim; then
  step "Neovim (mind. $NVIM_MIN_VERSION)"
  current="$(nvim_version)"

  if [[ -n "$current" ]] && version_ge "$current" "$NVIM_MIN_VERSION"; then
    ok "Neovim $current"
  elif [[ "$pm" == brew ]]; then
    if [[ -n "$current" ]] && brew list neovim >/dev/null 2>&1; then
      run brew upgrade neovim
    else
      run brew install neovim
    fi
  else
    # Die Distributionspakete sind oft zu alt für AstroNvim - offizielles Release verwenden.
    case "$arch" in
      x86_64|amd64) nvim_arch=x86_64 ;;
      aarch64|arm64) nvim_arch=arm64 ;;
      *) nvim_arch="" ;;
    esac
    if [[ -z "$nvim_arch" ]]; then
      warn "Kein offizielles Neovim-Release für $arch - bitte manuell installieren."
    else
      log "Installiere offizielles Neovim-Release nach ~/.local/opt/nvim"
      url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$nvim_arch.tar.gz"
      tmp="$(mktemp -d)"
      if run curl -fsSL "$url" -o "$tmp/nvim.tar.gz"; then
        run rm -rf "$HOME/.local/opt/nvim"
        run mkdir -p "$HOME/.local/opt/nvim" "$HOME/.local/bin"
        run tar -xzf "$tmp/nvim.tar.gz" -C "$HOME/.local/opt/nvim" --strip-components=1
        run ln -sfn "$HOME/.local/opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
      else
        warn "Download von $url fehlgeschlagen."
      fi
      rm -rf "$tmp"
    fi
  fi

  if ! ((dry_run)); then
    current="$(nvim_version)"
    if [[ -z "$current" ]]; then
      warn "Neovim ist nicht verfügbar."
    elif ! version_ge "$current" "$NVIM_MIN_VERSION"; then
      warn "Neovim $current ist älter als $NVIM_MIN_VERSION."
    else
      ok "Neovim $current"
    fi
  fi
fi

# --- claude -------------------------------------------------------------------

if wants claude; then
  step "Claude Code"
  if has claude; then
    ok "bereits installiert ($(claude --version 2>/dev/null | head -n1))"
  else
    if ((dry_run)); then
      log "[dry-run] curl -fsSL https://claude.ai/install.sh | bash"
    else
      curl -fsSL https://claude.ai/install.sh | bash || warn "Installation von Claude Code fehlgeschlagen."
    fi
  fi
fi

# --- codex --------------------------------------------------------------------

if wants codex; then
  step "Codex"
  if has codex; then
    ok "bereits installiert ($(codex --version 2>/dev/null | head -n1))"
  elif has npm || ((dry_run)); then
    # Nach ~/.local installieren: kein sudo nötig, Binary landet in ~/.local/bin.
    run npm install -g --prefix "$HOME/.local" @openai/codex || warn "Installation von Codex fehlgeschlagen."
  else
    warn "npm fehlt - Codex wird übersprungen."
  fi
fi

# --- herdr --------------------------------------------------------------------

if wants herdr; then
  step "herdr"
  if has herdr; then
    ok "bereits installiert ($(herdr --version 2>/dev/null | head -n1))"
  elif [[ "$pm" == brew ]]; then
    run brew install herdr || warn "Installation von herdr fehlgeschlagen."
  elif ((dry_run)); then
    log "[dry-run] curl -fsSL https://herdr.dev/install.sh | sh"
  else
    curl -fsSL https://herdr.dev/install.sh | sh || warn "Installation von herdr fehlgeschlagen."
  fi
fi

# --- font ---------------------------------------------------------------------

if wants font; then
  step "Nerd Font"
  if [[ "$os" == Darwin ]]; then
    if ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi 'nerd'; then
      ok "Nerd Font vorhanden"
    else
      run brew install --cask font-jetbrains-mono-nerd-font || warn "Font-Installation fehlgeschlagen."
    fi
  elif has fc-list && fc-list 2>/dev/null | grep -qi 'nerd font'; then
    ok "Nerd Font vorhanden"
  else
    font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    tmp="$(mktemp -d)"
    if run curl -fsSL "$url" -o "$tmp/font.zip"; then
      run mkdir -p "$font_dir"
      run unzip -oq "$tmp/font.zip" '*.ttf' -d "$font_dir"
      has fc-cache && run fc-cache -f "$font_dir" >/dev/null
      ok "JetBrainsMono Nerd Font installiert - im Terminal-Emulator auswählen."
    else
      warn "Download von $url fehlgeschlagen."
    fi
    rm -rf "$tmp"
  fi
fi

# --- repo ---------------------------------------------------------------------

# Läuft das Skript aus einem Klon heraus, wird dieser verwendet.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P)"
if [[ -n "${DOTFILES_DIR:-}" ]]; then
  repo="$DOTFILES_DIR"
elif [[ -n "$script_dir" && -d "$script_dir/.git" && -x "$script_dir/bin/.local/bin/dotfiles-sync" ]]; then
  repo="$script_dir"
else
  repo="$DEFAULT_DIR"
fi

if wants repo; then
  step "Repository ($repo)"
  if [[ ! -d "$repo/.git" ]]; then
    [[ -e "$repo" ]] && die "$repo existiert, ist aber kein Git-Repository."
    run git clone "$DOTFILES_REPO" "$repo" || die "git clone fehlgeschlagen."
  elif [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    warn "Lokale Änderungen im Repository - Update wird übersprungen."
  elif ! git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    warn "Kein Upstream konfiguriert - Update wird übersprungen."
  elif run git -C "$repo" pull --ff-only --quiet; then
    ok "aktuell ($(git -C "$repo" rev-parse --short HEAD))"
  else
    warn "Kein Fast-Forward möglich - bitte manuell auflösen."
  fi

  # dotfiles-sync und der systemd-Service erwarten das Repository unter ~/myDotfiles.
  if [[ "$(resolve "$repo")" != "$(resolve "$DEFAULT_DIR")" ]]; then
    if [[ ! -e "$DEFAULT_DIR" && ! -L "$DEFAULT_DIR" ]]; then
      run ln -s "$repo" "$DEFAULT_DIR" && log "$DEFAULT_DIR -> $repo verlinkt"
    else
      warn "$DEFAULT_DIR ist ein anderes Verzeichnis als $repo - dotfiles-sync nutzt ohne DOTFILES_DIR $DEFAULT_DIR."
    fi
  fi
fi

# Stow-Pakete wie in dotfiles-sync erkennen: Verzeichnisse mit mindestens einem Dotfile-Eintrag.
packages=()
if [[ -d "$repo" ]]; then
  for dir in "$repo"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -name '.*' -print -quit)" ]] && packages+=("$name")
  done
fi

# --- link ---------------------------------------------------------------------

is_fold_dir() {
  local rel="$1" f
  for f in $FOLD_DIRS; do [[ "$rel" == "$f" ]] && return 0; done
  return 1
}
under_fold_dir() {
  local rel="$1" f
  for f in $FOLD_DIRS; do [[ "$rel" == "$f" || "$rel" == "$f/"* ]] && return 0; done
  return 1
}

backup_dir="$DOTFILES_TARGET/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backed_up=0

# Verschiebt $DOTFILES_TARGET/<rel> ins Backup, sofern es nicht schon auf <src> zeigt.
backup_if_foreign() {
  local rel="$1" src="$2" dst="$DOTFILES_TARGET/$1"
  [[ -e "$dst" || -L "$dst" ]] || return 0
  [[ "$(resolve "$dst")" == "$(resolve "$src")" ]] && return 0
  run mkdir -p "$backup_dir/$(dirname "$rel")"
  run mv "$dst" "$backup_dir/$rel" && log "gesichert: ~/$rel"
  backed_up=$((backed_up + 1))
}

if wants link; then
  step "Verlinken mit GNU Stow (${packages[*]:-keine Pakete})"
  ((${#packages[@]})) || { ((dry_run)) || die "Keine Stow-Pakete in $repo gefunden."; }

  for pkg in "${packages[@]}"; do
    # Alte Links dieses Pakets entfernen, damit z. B. ein früher gefaltetes
    # ~/.claude -> Repo wieder zu einem echten Verzeichnis werden kann.
    (cd "$repo" && run stow --target="$DOTFILES_TARGET" --delete "$pkg" 2>/dev/null) || true

    # 1. Verzeichnisse, die als Ganzes verlinkt werden, komplett sichern.
    while IFS= read -r d; do
      rel="${d#"$repo/$pkg/"}"
      is_fold_dir "$rel" && backup_if_foreign "$rel" "$d"
    done < <(find "$repo/$pkg" -mindepth 1 -type d | sort)

    # 2. Übrige Verzeichnisse real anlegen (verhindert Folding ins Repository).
    while IFS= read -r d; do
      rel="${d#"$repo/$pkg/"}"
      under_fold_dir "$rel" && continue
      dst="$DOTFILES_TARGET/$rel"
      if [[ -L "$dst" || ( -e "$dst" && ! -d "$dst" ) ]]; then
        backup_if_foreign "$rel" "$d"
      fi
      [[ -d "$dst" ]] || run mkdir -p "$dst"
    done < <(find "$repo/$pkg" -mindepth 1 -type d | sort)

    # 3. Einzelne Dateien sichern, die Stow sonst als Konflikt melden würde.
    while IFS= read -r f; do
      rel="${f#"$repo/$pkg/"}"
      under_fold_dir "$rel" && continue
      backup_if_foreign "$rel" "$f"
    done < <(find "$repo/$pkg" -mindepth 1 \( -type f -o -type l \) | sort)
  done

  ((backed_up)) && log "Backup: $backup_dir"

  sync_args=(--no-pull)
  ((dry_run)) && sync_args+=(--dry-run)
  if [[ ! -x "$repo/bin/.local/bin/dotfiles-sync" ]]; then
    ((dry_run)) && log "[dry-run] dotfiles-sync --no-pull" || warn "$repo/bin/.local/bin/dotfiles-sync fehlt."
  elif DOTFILES_DIR="$repo" DOTFILES_TARGET="$DOTFILES_TARGET" \
      bash "$repo/bin/.local/bin/dotfiles-sync" "${sync_args[@]}" 2>&1 | sed 's/^/    /'; then
    ok "alle Pakete verlinkt"
  else
    warn "dotfiles-sync meldete Fehler (siehe oben)."
  fi
fi

# --- systemd ------------------------------------------------------------------

if wants systemd; then
  step "Automatische Aktualisierung"
  if [[ "$os" != Linux ]] || ! has systemctl; then
    log "kein systemd vorhanden - übersprungen (dotfiles-sync kann manuell ausgeführt werden)."
  elif ! systemctl --user show-environment >/dev/null 2>&1; then
    warn "Keine systemd-User-Sitzung erreichbar - später manuell: systemctl --user enable --now dotfiles-sync.service"
  else
    run systemctl --user daemon-reload
    # 'enable' ohne '--now': das Stowen ist gerade eben passiert.
    run systemctl --user enable dotfiles-sync.service && ok "dotfiles-sync.service aktiviert (läuft bei jedem Login)"
    if ((timer)); then
      run systemctl --user enable --now dotfiles-sync.timer && ok "dotfiles-sync.timer aktiviert (täglich)"
    else
      log "täglicher Timer nicht aktiviert (mit --timer einschalten)"
    fi
  fi
fi

# --- plugins ------------------------------------------------------------------

if wants plugins; then
  step "Neovim-Plugins"
  if ! has nvim && ! ((dry_run)); then
    warn "nvim fehlt - übersprungen."
  else
    run nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 &&
      ok "Plugins gemäß lazy-lock.json installiert" ||
      warn "Plugin-Installation fehlgeschlagen - beim nächsten Start von nvim prüfen."
  fi
fi

# --- mason --------------------------------------------------------------------

if wants mason; then
  step "Mason-Pakete"
  # Die Paketliste wird aus der README gelesen, damit sie nur an einer Stelle gepflegt wird.
  mason_pkgs="$(awk '/^:MasonInstall / { sub(/^:MasonInstall /, ""); print; exit }' "$repo/README.md" 2>/dev/null)"
  if [[ -z "$mason_pkgs" ]]; then
    warn "Keine ':MasonInstall'-Zeile in der README gefunden - übersprungen."
  elif ! has nvim && ! ((dry_run)); then
    warn "nvim fehlt - übersprungen."
  else
    log "$mason_pkgs"
    # Im Headless-Modus blockiert :MasonInstall, bis alle Pakete installiert sind.
    if run nvim --headless -c "MasonInstall $mason_pkgs" -c qall >/dev/null 2>&1; then
      ok "Mason-Pakete installiert"
    else
      warn "Mason meldete Fehler - in nvim mit :Mason prüfen."
    fi
  fi
fi

# --- tmux ---------------------------------------------------------------------

if wants tmux; then
  step "tmux"
  if has tmux && tmux info >/dev/null 2>&1; then
    run tmux source-file "$HOME/.tmux.conf" && ok "laufende Sitzung neu geladen"
  else
    log "keine laufende tmux-Sitzung"
  fi
fi

# --- Abschluss ----------------------------------------------------------------

step "Fertig"
if [[ ":$orig_path:" != *":$HOME/.local/bin:"* ]]; then
  log "~/.local/bin ist nicht im PATH (dort liegen dotfiles-sync, claude, codex, herdr). Zum Beispiel:"
  case "$(basename "${SHELL:-}")" in
    fish) log "  fish_add_path ~/.local/bin" ;;
    zsh) log "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc" ;;
    *) log "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc" ;;
  esac
fi
((warnings)) && printf '    %s%d Warnung(en) - siehe oben.%s\n' "$c_yellow" "$warnings" "$c_off"
exit 0
