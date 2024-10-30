# problem:
# * in x11 env, .profile has been sourced already
# * but in tty, .profile will not be sourced

emulate sh -c "source $HOME/.profile"
