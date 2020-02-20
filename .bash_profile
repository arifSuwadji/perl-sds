# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

CVSROOT=:ext:arif@ternate:/var/cvs/data
CVSEDITOR=vim
CVS_RSH=ssh
export CVSROOT CVSEDITOR CVS_RSH
