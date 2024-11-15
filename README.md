# 🐰 bunny.yazi

*🩷 Hop around your filesystem 🩷*

This is an intentionally simple directory bookmark plugin for [yazi](https://github.com/sxyazi/yazi).

- Define bookmarks (aka **hops**) in lua
- Change directory via key or fuzzy search with [fzf](https://github.com/junegunn/fzf) or any other compatible program
- Mark a directory (one at a time) for hopping quickly
- Single menu for all functionality, therefore only one keymap is required
- No filesystem changes whatsoever

<img src="https://i.imgur.com/3a47LI8.png" alt="bunny.yazi menu"/>

## Installation

### With `yapack`

```sh
ya pack -a stelcodes/bunny
```

### With Nix (Home Manager + flakes)

`flake.nix`:
```nix
inputs = {
  bunny-yazi = {
    url = "github:stelcodes/bunny.yazi";
    flake = false;
  };
};
```

Home Manager config:
```nix
programs.yazi = {
  plugins.bunny = builtins.toString inputs.bunny-yazi;
  initLua = ''
    require("bunny"):setup({ ... })
  '';
  keymap.manager.prepend_keymap = [
    { on = "'"; run = "plugin bunny"; desc = "Start bunny.yazi"; }
  ];
};
```

## Configuration
`~/.config/yazi/init.lua`:
```lua
local home = os.getenv("HOME")
require("bunny"):setup({
  hops = {
    { tag = "home", path = home, key = "h" },
    { tag = "nix-store", path = "/nix/store", key = "n" },
    { tag = "nix-config", path = home.."/.config/nix", key = "c" },
    { tag = "config", path = home.."/.config", key = "C" },
    { tag = "local", path = home.."/.local", key = "l" },
    { tag = "tmp-home", path = home.."/tmp", key = "t" },
    { tag = "tmp", path = "/tmp", key = "T" },
    { tag = "downloads", path = home.."/downloads", key = "d" },
    { tag = "music", path = home.."/music", key = "m" },
    { tag = "rekordbox", path = home.."/music/dj-tools/rekordbox", key = "r" },
  },
  notify = true, -- notify after hopping, default is false
  fuzzy_cmd = "sk", -- fuzzy searching command, default is fzf
})
```

`~/.config/yazi/yazi.toml`:
```toml
[[manager.prepend_keymap]]
desc = "Start bunny.yazi"
on = "'"
run = "plugin bunny"
```

## Inspiration

[yamb.yazi](https://github.com/h-hg/yamb.yazi)

[nnn bookmarks](https://github.com/jarun/nnn/wiki/Basic-use-cases#add-bookmarks)
