if test -f "$PWD/.lock"; then
  echo "Lock file present - Setup has already been ran"
  exit 0
fi

# Create Symlink
ln -s $PWD/.zsh $HOME/.zsh

# Add source to top of zshrc
ZSH_FILE=$HOME/.zshrc
SOURCE_CMD="source $PWD/base-zshrc \n"
{ echo $SOURCE_CMD; cat $ZSH_FILE; } > zshrc.new
mv -f zshrc.new $ZSH_FILE

echo "Setup complete, now just run source ~/.zshrc"

# Create lock
touch .lock
