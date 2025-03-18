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
  },
  notify = true, -- notify after hopping, default is false
})

Header:children_add(function(self)
  return "TESTING "
end, 1000, Header.RIGHT)
