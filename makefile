
# exclude all regular file and dotdir
entities ?= $(shell find . -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | grep -v '^\.' | tr -s '\n' ' ')


stow:
	stow -v1 --stow ${entities}
	@ # to prune obsolete symlinks
	@ stow --restow ${entities}

	touch ~/.config/fish/config.d/local.fish
	touch ~/.zshrc.local

build:
	cd compiles/.compiles                 && zig build -Doptimize=ReleaseFast
	cd nvim/.config/nvim/cthulhu          && zig build -Doptimize=ReleaseFast
	cd nvim/.config/nvim/hybrids/cricket  && zig build -Doptimize=ReleaseFast
	cd nvim/.config/nvim/hybrids/beckon   && zig build -Doptimize=ReleaseFast
	cd nvim/.config/nvim/hybrids/capsbulb && zig build -Doptimize=ReleaseFast

	if [ -f ~/bin/backlight ]; then sudo rm ~/bin/backlight; fi
	cp compiles/.compiles/zig-out/bin/* ~/bin/
	sudo chown root:root ~/bin/backlight && sudo chmod u+s ~/bin/backlight

pypacks:
	# batteries
	sudo pacman -Sy --needed python-attrs python-psutil python-requests
	# devtools
	sudo pacman -Sy --needed python-isort python-black
	@ # async batteries
	@ # sudo pacman -Sy --needed python-trio python-httpx python-hyperlink

update-subtrees:
	git subtree pull --prefix=scripts/.scripts/libs/ansi        https://github.com/fidian/ansi.git             master --squash
	#git subtree pull --prefix=scripts/.scripts/libs/vr-reversal https://github.com/haolian9/VR-reversal.git    master --squash

install: build pypacks stow

uninstall:
	stow -v1 --delete ${entities}

disk-gc:
	git gc --prune=now
	for dir in $$(find . -type d -name .zig-cache); do rm -rf $$dir; done
