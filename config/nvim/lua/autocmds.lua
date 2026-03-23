require "nvchad.autocmds"

vim.api.nvim_create_autocmd({ "InsertLeave", "FocusLost" }, {
  pattern = "*",
  callback = function()
    if vim.bo.modified and not vim.bo.readonly and vim.fn.expand "%h" ~= "" then
      vim.cmd "silent! write"
    end
  end,
  desc = "Autosave on leaving insert mode or losing focus",
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.spell = true
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
  desc = "Markdown settings",
})

-- Auto-close love2d debug window when game exits
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    local love2d = require "love2d"
    local original_run = love2d.run
    love2d.run = function(path)
      local original_jobstart = vim.fn.jobstart
      vim.fn.jobstart = function(cmd, opts)
        local original_on_exit = opts.on_exit
        opts.on_exit = function(id, code)
          if original_on_exit then original_on_exit(id, code) end
          if love2d.debug_window and vim.api.nvim_win_is_valid(love2d.debug_window) then
            vim.api.nvim_win_close(love2d.debug_window, true)
          end
        end
        local id = original_jobstart(cmd, opts)
        vim.fn.jobstart = original_jobstart
        return id
      end
      original_run(path)
    end
  end,
})
