return {
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

  -- 1. Plugin pour gérer les versions dans Cargo.toml
  {
    "saecki/crates.nvim",
    ft = { "toml" },
    config = function()
      require("crates").setup()
      require("crates").show()
    end,
  },

  -- 2. Le plugin Rust tout-en-un (remplace rust-tools)
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    lazy = false,
    config = function()
      local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/"
      local codelldb_path = mason_path .. "adapter/codelldb"
      local liblldb_path = mason_path .. "lldb/lib/liblldb.so"

      vim.g.rustaceanvim = {
        -- Configuration du Debugger (DAP)
        dap = {
          adapter = require("rustaceanvim.config").get_codelldb_adapter(codelldb_path, liblldb_path),
        },
        -- Configuration du Serveur (LSP)
        server = {
          on_attach = function(client, bufnr)
            -- Changez 'true' par 'false' ici pour démarrer caché
            if client.server_capabilities.inlayHintProvider then
              vim.lsp.inlay_hint.enable(false, { bufnr = bufnr }) 
            end
          end,
          default_settings = {
            -- Options spécifiques pour rust-analyzer
            ['rust-analyzer'] = {
              inlayHints = {
                bindingModeHints = { enable = false },
                chainingHints = { enable = true },
                closingBraceHints = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "always" },
                lifetimeElisionHints = { enable = "always", useParameterNames = true },
                maxLength = 25,
                parameterHints = { enable = true },
                reborrowHints = { enable = "always" },
                renderColons = true,
                typeHints = { enable = true, hideClosureInitialization = false, hideNamedConstructor = false },
              },
            },
          },
        },
      }
    end
  },

  -- 1. Le moteur de débogage (nvim-dap)
  {
    "mfussenegger/nvim-dap",
    lazy = false, -- On le charge tout de suite pour avoir les commandes dispos
  },

  -- 2. L'interface graphique de débogage (nvim-dap-ui)
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()

      -- Ouverture automatique de l'interface quand on lance le debug
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      -- Fermeture automatique quand on arrête
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end
  },

  -- 3. Configuration de Mason pour s'assurer que le debuggeur est là
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server",
        "codelldb", -- Indispensable pour le debug Rust
      },
    },
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
