local M = {}

function M.setup(opts)
  local config = require("jeancode.config")
  config.setup(opts)

  local watcher = require("jeancode.watcher")
  watcher.setup()

  local commands = require("jeancode.commands")
  commands.setup()

  local keymaps = require("jeancode.keymaps")
  keymaps.setup()

  -- Clean up buffers file when Neovim exits
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local terminal = require("jeancode.terminal")
      terminal.destroy()
    end,
  })
end

function M.toggle()
  local terminal = require("jeancode.terminal")
  local watcher = require("jeancode.watcher")
  local window = require("jeancode.window")
  local state = terminal.get_state()

  -- Capture the source buffer BEFORE toggling (so we know what file the user was on)
  local source_bufnr = vim.api.nvim_get_current_buf()

  if window.is_visible(state.win_id) then
    -- Toggling off
    terminal.toggle()
    watcher.stop()
  else
    -- Toggling on - pass source buffer for context (used by spawn's --append-system-prompt)
    terminal.toggle(source_bufnr)
    watcher.start()
  end
end

function M.new_session()
  local terminal = require("jeancode.terminal")
  local watcher = require("jeancode.watcher")
  terminal.new_session()
  watcher.start()
end

function M.toggle_layout()
  require("jeancode.layout").toggle()
end

function M.toggle_float()
  require("jeancode.layout").float()
end

function M.send_selection()
  require("jeancode.sender").send_selection()
end

return M
