
# exclude all regular file and dotdir
entities ?= $(shell find . -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | grep -v '^\.' | tr -s '\n' ' ')


install: build
	stow -v1 --stow ${entities}
	@ # to prune obsolete symlinks
	@ stow --restow ${entities}

build:
	cd compiles/.compiles && zig build -Drelease-safe
	cd nvim/.config/nvim/cthulhu && zig build -Drelease-safe

uninstall:
	stow -v1 --delete ${entities}

update-subtrees:
	git subtree pull --prefix=scripts/.scripts/libs/ansi        https://github.com/fidian/ansi.git           master --squash
	git subtree pull --prefix=tmux/.tmux/plugins/tpm            https://github.com/tmux-plugins/tpm.git      master --squash
	git subtree pull --prefix=scripts/.scripts/libs/vr-reversal https://github.com/haolian9/VR-reversal.git  master --squash
	git subtree pull --prefix=zsh/.config/zsh-comp/zig          https://github.com/ziglang/shell-completions master --squash

