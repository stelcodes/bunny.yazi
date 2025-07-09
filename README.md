# bunny.yazi 🐰

*🩷 Hop around your filesystem 🩷*

This is a bookmark plugin for [yazi](https://github.com/sxyazi/yazi) which augments the builtin bookmarking abilities into a single menu of `cd` powers designed with user experience (and cuteness) in mind. Bookmarks are referred to as *hops* because users should always feel adorable while using their terminal.

## Features

- Create persistent hops in your `init.lua` config file
- Create ephemeral hops while using yazi
- Hop to any directory open in another tab
- Hop back to previous directory (history is associated with tab number)
- Hop by fuzzy searching available hops with [fzf](https://github.com/junegunn/fzf) or similar program
- Single menu for all functionality, therefore only one keymap is required in your `keymap.toml` file
- Hands off: no reads or writes to your filesystem, all state is kept in memory

<img src="https://i.imgur.com/9OKQJUT.png" alt="bunny.yazi menu open in a terminal"/>

## Installation

### With `git`

```sh
git clone https://github.com/stelcodes/bunny.yazi ~/.config/yazi/plugins/bunny.yazi
```

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
  keymap.mgr.prepend_keymap = [
    { on = ";"; run = "plugin bunny"; desc = "Start bunny.yazi"; }
  ];
};
```

## Configuration
`~/.config/yazi/init.lua`:
```lua
require("bunny"):setup({
  hops = {
    { key = "/",          path = "/",                                    },
    { key = "t",          path = "/tmp",                                 },
    { key = "n",          path = "/nix/store",     desc = "Nix store"    },
    { key = "~",          path = "~",              desc = "Home"         },
    { key = "m",          path = "~/Music",        desc = "Music"        },
    { key = "d",          path = "~/Desktop",      desc = "Desktop"      },
    { key = "D",          path = "~/Documents",    desc = "Documents"    },
    { key = "c",          path = "~/.config",      desc = "Config files" },
    { key = { "l", "s" }, path = "~/.local/share", desc = "Local share"  },
    { key = { "l", "b" }, path = "~/.local/bin",   desc = "Local bin"    },
    { key = { "l", "t" }, path = "~/.local/state", desc = "Local state"  },
    -- key and path attributes are required, desc is optional
  },
  desc_strategy = "path", -- If desc isn't present, use "path" or "filename", default is "path"
  ephemeral = true, -- Enable ephemeral hops, default is true
  tabs = true, -- Enable tab hops, default is true
  notify = false, -- Notify after hopping, default is false
  fuzzy_cmd = "fzf", -- Fuzzy searching command, default is "fzf"
})
```

`~/.config/yazi/keymap.toml`:
```toml
[[mgr.prepend_keymap]]
desc = "Start bunny.yazi"
on = ";"
run = "plugin bunny"

# Optionally, add another keymap to immediately fuzzy search bookmarks
[[mgr.prepend_keymap]]
desc = "Start bunny.yazi fuzzy search"
on = "'"
run = "plugin bunny fuzzy"
```

## Inspiration

[yamb.yazi](https://github.com/h-hg/yamb.yazi)

[nnn bookmarks](https://github.com/jarun/nnn/wiki/Basic-use-cases#add-bookmarks)
