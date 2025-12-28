require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Raccourcis pour le Debugging (DAP)
map("n", "<leader>db", "<cmd> DapToggleBreakpoint <CR>", { desc = "Debug: Toggle Breakpoint" })
map("n", "<leader>dr", "<cmd> DapContinue <CR>", { desc = "Debug: Start/Continue" })
map("n", "<leader>du", "<cmd> lua require('dapui').toggle() <CR>", { desc = "Debug: Toggle UI" })
map("n", "<leader>dx", "<cmd> DapTerminate <CR>", { desc = "Debug: Stop" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")


-- Raccourci pour basculer les Inlay Hints (Leader + t + h)
map("n", "<leader>ti", function()
  local is_enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
  vim.lsp.inlay_hint.enable(not is_enabled, { bufnr = 0 })
  
  if is_enabled then
    print("Inlay Hints: OFF 🙈")
  else
    print("Inlay Hints: ON 👀")
  end
end, { desc = "LSP | Toggle Inlay Hints" })
