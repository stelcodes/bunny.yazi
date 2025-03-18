# bunny.yazi 🐰

*🩷 Hop around your filesystem 🩷*

This is an intentionally simple yet effective directory bookmark plugin for [yazi](https://github.com/sxyazi/yazi).

Bookmarks are referred to as *hops* because maximizing cuteness is a top priority.

## Features

- Create persistent hops in your `init.lua` config file (lowercase letters only)
- Create ephemeral hops while using yazi (uppercase letters only)
- Hop to any directory open in another tab
- Hop back to previous directory (history is associated with tab number)
- Hop by fuzzy searching all available hops with [fzf](https://github.com/junegunn/fzf) or similar program
- Single menu for all functionality, therefore only one keymap is required in your `keymap.toml` file
- Hands off: no reads or writes to your filesystem, all state is kept in memory

<!-- <img src="https://i.imgur.com/3a47LI8.png" alt="bunny.yazi menu"/> -->

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
  plugins.bunny = "${inputs.bunny-yazi}";
  initLua = ''
    require("bunny"):setup({ ... })
  '';
  keymap.manager.prepend_keymap = [
    { on = ";"; run = "plugin bunny"; desc = "Start bunny.yazi"; }
  ];
};
```

## Configuration
`~/.config/yazi/init.lua`:
```lua
local home = os.getenv("HOME")
require("bunny"):setup({
  hops = {
    { key = "r", path = "/", desc = "Root" },
    { key = "t", path = "/tmp", desc = "Temp files" },
    { key = { "h", "h" }, path = home, desc = "Home" },
    { key = { "h", "m" }, path = home.."/Music" },
    { key = { "h", "d" }, path = home.."/Documents" },
    { key = { "h", "k" }, path = home.."/Desktop" },
    { key = { "n", "c" }, path = home.."/.config/nix", desc = "Nix config" },
    { key = { "n", "s" }, path = "/nix/store", desc = "Nix store" },
    { key = "c", path = home.."/.config", desc = "Config files" },
    { key = { "l", "s" }, path = home.."/.local/share", desc = "Local share" },
    { key = { "l", "b" }, path = home.."/.local/bin", desc = "Local bin" },
    { key = { "l", "t" }, path = home.."/.local/state", desc = "Local state" },
    -- key and path attributes are required, desc is optional
  },
  notify = true, -- notify after hopping, default is false
  fuzzy_cmd = "sk", -- fuzzy searching command, default is fzf
})
```

`~/.config/yazi/yazi.toml`:
```toml
[[manager.prepend_keymap]]
desc = "Start bunny.yazi"
on = ";"
run = "plugin bunny"
```

## Inspiration

[yamb.yazi](https://github.com/h-hg/yamb.yazi)

[nnn bookmarks](https://github.com/jarun/nnn/wiki/Basic-use-cases#add-bookmarks)
