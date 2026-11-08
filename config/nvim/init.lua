-- supershell Neovim profile (Neovim 0.12+)
-- Small on purpose: built-in LSP client, built-in completion, built-in package
-- manager (vim.pack) and five plugins. Read top to bottom in a few minutes.
--
-- Lives in ~/.config/supershell-nvim and runs with NVIM_APPNAME=supershell-nvim,
-- so it never touches an existing ~/.config/nvim.

if vim.fn.has("nvim-0.12") == 0 then
  vim.api.nvim_echo({ { "supershell profile needs Neovim 0.12 or newer", "WarningMsg" } }, true, {})
  return
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.supershell_icons = (vim.env.SUPERSHELL_ICONS == "nerd")

require("supershell.options")
require("supershell.keymaps")
require("supershell.plugins")
require("supershell.lsp")
require("supershell.arabic")
