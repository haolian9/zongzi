
实现基于 [stow](https://www.gnu.org/software/stow/), 启发自 [Using GNU Stow to manage your dotfiles](http://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html)


setup checklist
---

* pypacks
* tmux tpm
* powerlevel10k
* NVIM_PROFILES=all nvim +PluginInstall
* cd ~/.compiles && zig build -Drelease-safe
* cd ~/.config/nvim/cthulhu && zig build -Drelease-safe


relevant programs or resources
---

font:
* adobe-source-\* 及其 nerd font
* noto-fonts-emoji
* [monego](https://github.com/cseelus/monego)

xcursor themes:
* [Capitaine](https://www.pling.com/p/1148692) [pacman capitaine-cursors]
* [Oreo](https://www.pling.com/p/1360254)
* [Layan](https://www.pling.com/p/1365214)

programs:
* [palantir](git@gitlab.com:haoliang-incubator/palantir.git)
* [delta](https://github.com/dandavison/delta)
* trojan
* direnv
* [umbra](git@gitlab.com:haoliang-incubator/umbra.git)
