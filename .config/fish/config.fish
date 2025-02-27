if status is-interactive
    # Commands to run in interactive sessions can go here
end

if type -q exa
    alias ll="exa -l -g --icons"
    alias la="exa -l -g -a --icons"
end

if type -q python3
    alias python="python3"
    alias pip="pip3"
    alias py="python3"
end

if type -q git
    alias gstat "git status"
    alias gadd "git add ."
    alias gcomm "git commit -m"
    alias gpush "git push"
    alias gpull "git pull"
end

function __auto_source_venv --on-variable PWD --description "Activate/Deactivate virtualenv on directory change"
  status --is-command-substitution; and return

  # Check if we are inside a git directory
  if git rev-parse --show-toplevel &>/dev/null
    set gitdir (realpath (git rev-parse --show-toplevel))
  else
    set gitdir ""
  end

  # If venv is not activated or a different venv is activated and venv exist.
  if test "$VIRTUAL_ENV" != "$gitdir/.venv" -a -e "$gitdir/.venv/bin/activate.fish"
    source $gitdir/.venv/bin/activate.fish
  # If venv activated but the current (git) dir has no venv.
  else if not test -z "$VIRTUAL_ENV" -o -e "$gitdir/.venv"
    deactivate
  end
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Auto-Warpify
printf 'P$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "fish", "uname": "Darwin" }}œ' 
