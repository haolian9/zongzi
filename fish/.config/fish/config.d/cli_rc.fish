
set -x GOPATH ~/.go
set -x GO111MODULE on
# or https://mirrors.aliyun.com/goproxy/
set -x GOPROXY https://mirrors.cloud.tencent.com/go/

set -x FZF_DEFAULT_OPTS --multi --cycle --no-hscroll --ansi --info=inline --no-mouse --bind space:accept

if test "$BGMODE" = dark
    set -x LS_COLORS 'di=97:fi=97:ln=97'
else
    set -x LS_COLORS 'di=30:fi=30:ln=30'
end
