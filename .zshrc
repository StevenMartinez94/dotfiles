# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load.
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

# Fix colorscheme for kitty terminal during SSH sessions
export TERM=xterm-256color

# Enable ZSH
source $ZSH/oh-my-zsh.sh

# Enable custom plugins
source $ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh