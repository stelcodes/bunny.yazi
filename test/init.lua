local home = os.getenv("HOME")
require("bunny"):setup({
  hops = {
    { tag = "home", path = home, key = "h" },
    { tag = "root", path = "/", key = "r" },
  },
  notify = true, -- notify after hopping, default is false
})

Header:children_add(function(self)
  return "TESTING "
end, 1000, Header.RIGHT)
