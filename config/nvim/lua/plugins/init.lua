return {
  {
    "hrsh7th/nvim-cmp",
    opts = function()
      local cmp = require "cmp"
      local opts = require "nvchad.configs.cmp"
      opts.mapping["<CR>"] = cmp.mapping(function(fallback)
        fallback()
      end)
      opts.mapping["<Tab>"] = cmp.mapping(function(fallback)
        fallback()
      end)
      opts.mapping["<C-y>"] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Insert,
        select = true,
      }
      return opts
    end,
  },

  {
    "github/copilot.vim",
    lazy = false,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "lua", "vim", "vimdoc", "markdown", "markdown_inline" },
      endwise = { enable = true },
    },
  },

  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npm install",
    ft = "markdown",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop" },
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreview<cr>", desc = "Markdown Preview" },
      { "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", desc = "Markdown Preview Stop" },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
  },

  {
    "RRethy/nvim-treesitter-endwise",
    lazy = false,
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },

  {
    "S1M0N38/love2d.nvim",
    event = "VeryLazy",
    version = "2.*",
    opts = {
      path_to_love_bin = "stdbuf -oL -eL love",
      debug_window_opts = {
        relative = "editor",
        width = 60,
        height = 15,
        row = 1,
        col = 1,
        style = "minimal",
        border = "rounded",
      },
    },
    keys = {
      { "<leader>v", ft = "lua", desc = "LÖVE" },
      { "<leader>vv", "<cmd>LoveRun<cr>", ft = "lua", desc = "Run LÖVE" },
      { "<leader>vs", "<cmd>LoveStop<cr>", ft = "lua", desc = "Stop LÖVE" },
    },
  },

  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
