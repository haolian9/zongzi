# the same as ~/.profile

# in archlinux
# * /bin linked to /usr/bin
# * /usr/sbin /sbin linked to /usr/bin
set -gx PATH
set PATH ~/.scripts ~/bin ~/.local/bin
# see /etc/profilee
set -a PATH /usr/bin /usr/local/bin
if fish_is_root_user
    set -a PATH /usr/local/sbin
end

# see /etc/profile.d/locale.sh
set -x LC_ALL en_US.UTF-8
set -x LANG en_US.UTF-8

set -x EDITOR nvim
set -x PAGER less
