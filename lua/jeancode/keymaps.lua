local M = {}

function M.setup()
  local config = require("jeancode.config")
  local cfg = config.options

  -- <Plug> mappings (always available)
  vim.keymap.set("n", "<Plug>(jeancode-toggle)", function()
    require("jeancode").toggle()
  end, { desc = "Toggle Claude Code panel" })

  vim.keymap.set("v", "<Plug>(jeancode-send)", function()
    require("jeancode").send_selection()
  end, { desc = "Send selection to Claude Code" })

  vim.keymap.set("t", "<Plug>(jeancode-toggle)", function()
    require("jeancode").toggle()
  end, { desc = "Toggle Claude Code panel (terminal)" })

  -- Default keymaps (configurable, false to disable)
  if cfg.keymaps.toggle then
    vim.keymap.set("n", cfg.keymaps.toggle, "<Plug>(jeancode-toggle)", { desc = "Toggle Claude Code panel" })
    -- Terminal mode toggle: use <C-\><C-n> to exit terminal first, then toggle
    vim.keymap.set("t", cfg.keymaps.toggle, function()
      require("jeancode").toggle()
    end, { desc = "Toggle Claude Code panel (terminal)" })
  end

  if cfg.keymaps.send then
    vim.keymap.set("v", cfg.keymaps.send, "<Plug>(jeancode-send)", { desc = "Send selection to Claude Code" })
  end
end

return M
