require("bunny"):setup({
  hops = {
    { key = "r", path = "/", desc = "Root" },
    { key = "t", path = "/tmp", desc = "Temp files" },
    { key = "b", path = "/opt/homebrew", desc = "Brew" },
    { key = { "h", "h" }, path = "~", desc = "Home" },
    { key = { "h", "m" }, path = "~/Music", desc = "Music" },
    { key = { "h", "d" }, path = "~/Documents", desc = "Documents" },
    { key = { "h", "k" }, path = "~/Desktop", desc = "Desktop" },
    { key = { "n", "c" }, path = "~/.config/nix", desc = "Nix config" },
    { key = { "n", "s" }, path = "/nix/store", desc = "Nix store" },
    { key = "c", path = "~/.config", desc = "Config files" },
    { key = { "l", "s" }, path = "~/.local/share", desc = "Local share" },
    { key = { "l", "b" }, path = "~/.local/bin", desc = "Local bin" },
    { key = { "l", "t" }, path = "~/.local/state", desc = "Local state" },
    { key = "u", path = "/usr" },
    { key = "v", path = "/Volumes" },
  },
  -- desc_strategy = "filename",
  notify = true, -- notify after hopping, default is false
  fuzzy_cmd = "fzf",
})

Header:children_add(function(self)
  return "TESTING "
end, 1000, Header.RIGHT)
