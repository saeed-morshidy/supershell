-- Language servers (name → Mason package). A server is enabled only if its program is installed, so a
-- missing one never produces errors. Install servers with :Mason, or all the
-- recommended ones at once with :SupershellLspInstall (needs network, node for some).

local servers = {
  bashls = "bash-language-server",
  pyright = "pyright",
  gopls = "gopls",
  yamlls = "yaml-language-server",
  jsonls = "json-lsp",
  dockerls = "dockerfile-language-server",
  terraformls = "terraform-ls",
  marksman = "marksman",
  lua_ls = "lua-language-server",
}

vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      schemaStore = { enable = true },
      schemas = {
        kubernetes = { "k8s/**/*.yaml", "kubernetes/**/*.yaml", "*.k8s.yaml", "manifests/**/*.yaml" },
      },
    },
  },
})
vim.lsp.config("lua_ls", { settings = { Lua = { diagnostics = { globals = { "vim", "MiniIcons", "MiniFiles" } } } } })

for name in pairs(servers) do
  local cfg = vim.lsp.config[name]
  local cmd = cfg and cfg.cmd
  if type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1 then
    vim.lsp.enable(name)
  end
end

vim.api.nvim_create_user_command("SupershellLspInstall", function()
  local reg = require("mason-registry")
  reg.refresh(function()
    for _, pkg in pairs(servers) do
      local ok, p = pcall(reg.get_package, pkg)
      if ok and not p:is_installed() then p:install() end
    end
    vim.notify("Installing language servers in the background — see :Mason. Restart Neovim when done.")
  end)
end, { desc = "Install the recommended language servers" })

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local o = function(desc) return { buffer = ev.buf, desc = desc } end
    local map = vim.keymap.set
    map("n", "gd", vim.lsp.buf.definition, o("Go to definition"))
    map("n", "gr", vim.lsp.buf.references, o("References"))
    map("n", "<leader>ca", vim.lsp.buf.code_action, o("Code action"))
    map("n", "<leader>cr", vim.lsp.buf.rename, o("Rename"))
    map({ "n", "x" }, "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, o("Format"))
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})
