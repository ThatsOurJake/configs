NEWLINE='\n'

host_name() {
  echo "%B%F{146}[$(hostname)]%f%b "
}

current_branch() {
  echo $(git branch | grep '* ' | sed 's/* //')
}

prompt_dir() {
  if [[ $(pwd) == $HOME ]]
  then
    echo "~"
  else
    basename=$(pwd | xargs basename | sed 's/^\///')
    parent_path=$(cd .. && pwd | sed 's/\/$//' | sed 's,^'"$HOME"',~,')
    echo "%F{008}$parent_path%f/$basename"
  fi
}

git_is_clean() {
  [[ -z $(git status -s) ]]
}

is_git_directory() {
  [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1
}

prompt_git() {
  if is_git_directory && git_is_clean; then
      echo " %F{008}on%f %F{green}$(current_branch)%f"
  elif is_git_directory; then
      echo " %F{008}on%f %F{red}$(current_branch)%f"
  fi
}

prompt_rainbow_arrow() {
  echo "%F{red}⟫%F{yellow}⟫%F{green}⟫%F{blue}⟫%F{098}⟫%f"
}

prompt_mode() {
  [[ $1 != "" ]] && echo " %F{008}(%F{003}$1%F{008})%f"
}

prompt_left() {
  echo "$(host_name)$(prompt_dir)$(prompt_git)$(prompt_mode $1)$NEWLINE $(prompt_rainbow_arrow) "
}

precmd() {
  PROMPT="$(prompt_left)"
}
