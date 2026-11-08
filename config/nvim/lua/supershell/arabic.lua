-- Arabic / right-to-left text.
--
-- In a VTE terminal (Ptyxis, GNOME Terminal) the terminal itself reorders and
-- shapes Arabic. Neovim must therefore NOT reorder or shape it again:
--   termbidi    = the terminal is in charge of bidirectional text
--   arabicshape = off (the terminal shapes letters)
-- Known limitation (see docs/arabic.md): Neovim keeps the cursor in logical
-- order, so in mixed Arabic/English lines the cursor can look out of place
-- while the text itself displays correctly.

pcall(function() vim.opt.termbidi = true end)
pcall(function() vim.opt.arabicshape = false end)

-- :ArabicView — experimental: lay a window out right-to-left for reading or
-- writing a whole Arabic document. Run it again to switch back.
vim.api.nvim_create_user_command("ArabicView", function()
  local rl = not vim.wo.rightleft
  vim.wo.rightleft = rl
  vim.notify(rl and "Right-to-left window (experimental)" or "Left-to-right window")
end, { desc = "Toggle right-to-left layout for this window" })
