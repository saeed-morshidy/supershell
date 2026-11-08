local o = vim.opt

o.number = true
o.relativenumber = false     -- plain numbers are friendlier when learning
o.signcolumn = "yes"
o.cursorline = true
o.mouse = "a"
o.termguicolors = false      -- use the terminal's own palette (light & dark)
o.scrolloff = 6
o.wrap = false
o.linebreak = true
o.breakindent = true
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.undofile = true            -- undo survives closing the file
o.updatetime = 250
o.timeoutlen = 400
o.confirm = true             -- ask instead of failing on :q with changes
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.completeopt = { "menuone", "noselect", "popup", "fuzzy" }
o.pumheight = 12
o.laststatus = 3
o.showmode = false

-- System clipboard: wl-clipboard on the desktop; over SSH Neovim uses OSC 52.
o.clipboard = "unnamedplus"

-- Languages that conventionally use 4 spaces or tabs.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "dockerfile" },
  callback = function() vim.bo.shiftwidth = 4; vim.bo.tabstop = 4 end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go", "make" },
  callback = function() vim.bo.expandtab = false; vim.bo.shiftwidth = 4; vim.bo.tabstop = 4 end,
})

-- Briefly highlight what you yank.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

-- Kubernetes / Helm / Compose files are YAML.
vim.filetype.add({
  extension = { tf = "terraform", tfvars = "terraform", hcl = "hcl" },
  filename = { ["Containerfile"] = "dockerfile" },
  pattern = { [".*/templates/.*%.ya?ml"] = "helm", ["docker%-compose.*%.ya?ml"] = "yaml.docker-compose" },
})
