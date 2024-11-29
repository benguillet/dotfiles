## dot-files

### Quickstart
1. Set dotfiles repo public temporarily: https://github.com/benguillet/dotfiles
2. Clone repo:
```bash
git clone https://github.com/benguillet/dotfiles.git
```
3. Install zim
```
rake zim
```
4. Install brew and essential cli tools
```
rake brew
```
5. Log into 1password and dropbox; start syncing
6. Run symlinks script (when Dropbox is done syncing)
```
rake symlinks
```
7. Install zimfw install for new modules
```
zimfw install
```
8. Set Mac OS preferred settings
```
rake macos
```

### Zim
- Added new modules to ~/.zimrc? Run zimfw install.
- Removed modules from ~/.zimrc? Run zimfw uninstall.
- Want to update your modules to their latest revisions? Run zimfw update.
- Want to upgrade zimfw to its latest version? Run zimfw upgrade.
- For more information about the zimfw plugin manager, run zimfw help.

### Useful links
- List of Mac OS settings:
    - https://gist.github.com/millermedeiros/6615994
    - https://github.com/mathiasbynens/dotfiles/blob/master/.macos
- GitX: https://github.com/gitx/gitx
    - Don't forget to enable Terminal usage