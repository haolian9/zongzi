# the same as ~/.profile

# in archlinux
# * /bin linked to /usr/bin
# * /usr/sbin /sbin linked to /usr/bin
set -gx PATH
set -a PATH ~/.alias ~/.scripts
set -a PATH ~/bin ~/.local/bin
# see /etc/profile
set -a PATH /usr/bin /usr/local/bin
if fish_is_root_user
    set -a PATH /usr/local/sbin
end

# see /etc/profile.d/locale.sh
set -x LC_ALL en_US.UTF-8
set -x LANG en_US.UTF-8

set -x EDITOR nvim
set -x PAGER less

export GOPATH=~/.go
export GO111MODULE=on
# or https://mirrors.aliyun.com/goproxy/
# or https://mirrors.cloud.tencent.com/go/
export GOPROXY=https://goproxy.cn
