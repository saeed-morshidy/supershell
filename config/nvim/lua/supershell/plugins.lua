-- Five plugins, installed by Neovim's built-in vim.pack. Versions are recorded in
-- nvim-pack-lock.json (commit it if you fork this profile).
--   :lua vim.pack.update()   review and apply updates

local gh = function(repo) return "https://github.com/" .. repo end

vim.pack.add({
  { src = gh("neovim/nvim-lspconfig") },                 -- server definitions
  { src = gh("mason-org/mason.nvim") },                  -- installs language servers
  { src = gh("nvim-mini/mini.nvim"), version = "stable" },-- statusline, file browser, key hints, icons
  { src = gh("ibhagwan/fzf-lua") },                      -- uses the same fzf/rg/fd as the shell
  { src = gh("lewis6991/gitsigns.nvim") },               -- git changes in the margin
}, { confirm = false })

require("mason").setup({ ui = { border = "rounded" } })

-- mini.nvim ---------------------------------------------------------------------
if vim.g.supershell_icons then
  require("mini.icons").setup()
  MiniIcons.mock_nvim_web_devicons()
end
require("mini.statusline").setup({ use_icons = vim.g.supershell_icons })
require("mini.files").setup({ options = { use_as_default_explorer = false } })
require("mini.clue").setup({
  triggers = {
    { mode = "n", keys = "<Leader>" }, { mode = "x", keys = "<Leader>" },
    { mode = "n", keys = "g" }, { mode = "n", keys = "]" }, { mode = "n", keys = "[" },
    { mode = "n", keys = "<C-w>" }, { mode = "n", keys = "z" },
  },
  clues = {
    require("mini.clue").gen_clues.g(), require("mini.clue").gen_clues.windows(),
    require("mini.clue").gen_clues.z(),
    { mode = "n", keys = "<Leader>c", desc = "+code" }, { mode = "n", keys = "<Leader>g", desc = "+git" },
  },
  window = { delay = 300 },
})

-- fzf-lua ---------------------------------------------------------------------
local fzf = require("fzf-lua")
fzf.setup({ "default", winopts = { border = "rounded", preview = { layout = "vertical" } },
  defaults = { file_icons = vim.g.supershell_icons } })
local map = vim.keymap.set
map("n", "<leader>f", fzf.files, { desc = "Find file" })
map("n", "<leader>/", fzf.live_grep, { desc = "Search text in project" })
map("n", "<leader>b", fzf.buffers, { desc = "Open buffers" })
map("n", "<leader>h", fzf.oldfiles, { desc = "Recent files" })
map("n", "<leader>s", fzf.lsp_document_symbols, { desc = "Symbols in file" })
map("n", "<leader>e", function() MiniFiles.open(vim.api.nvim_buf_get_name(0)) end, { desc = "File browser" })

-- gitsigns --------------------------------------------------------------------
require("gitsigns").setup({
  on_attach = function(buf)
    local gs = require("gitsigns")
    local o = function(desc) return { buffer = buf, desc = desc } end
    map("n", "]h", function() gs.nav_hunk("next") end, o("Next change"))
    map("n", "[h", function() gs.nav_hunk("prev") end, o("Previous change"))
    map("n", "<leader>gp", gs.preview_hunk, o("Preview change"))
    map("n", "<leader>gb", gs.blame_line, o("Who changed this line"))
    map("n", "<leader>gr", gs.reset_hunk, o("Undo this change"))
  end,
})
