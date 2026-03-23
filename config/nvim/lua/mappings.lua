require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- jump past closing bracket/paren/quote in insert mode
map("i", "<C-l>", function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local next_char = line:sub(col + 1, col + 1)
  if next_char:match "[%)%]%}\"'`]" then
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], col + 1 })
  end
end, { desc = "Jump past closing bracket" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

local m = require "nvchad.mappings"

map("n", "<leader>m=", function()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_set_current_line(line .. "=")
end, { desc = "Add =" })

map("n", "<leader>m-", function()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_set_current_line(line .. "-")
end, { desc = "Add -" })

map("n", "<leader>m]", "a](", { desc = "Add link brackets" })
map("i", "<leader>m]", "[]()", { desc = "Add link brackets" })
