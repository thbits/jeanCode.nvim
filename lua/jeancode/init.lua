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
  local config = require("jeancode.config")
  local terminal = require("jeancode.terminal")
  local window = require("jeancode.window")
  local state = terminal.get_state()

  -- Only works when the window is visible
  if not window.is_visible(state.win_id) then
    vim.notify("jeancode: panel is not open", vim.log.levels.WARN)
    return
  end

  -- Cycle position: right -> bottom -> left -> right
  local cycle = { right = "bottom", bottom = "left", left = "right" }
  local cur = config.options.window.position
  local next_pos = cycle[cur] or "right"
  config.options.window.position = next_pos

  -- Close current window and reopen with new position
  window.close(state.win_id)
  state.win_id = window.open(state.bufnr, config.options.window)
  if config.options.window.enter_insert then
    vim.cmd("startinsert")
  end
  vim.notify("jeancode: layout → " .. next_pos, vim.log.levels.INFO)
end

function M.send_selection()
  local terminal = require("jeancode.terminal")

  -- Capture file context BEFORE any window changes
  local file = vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype

  -- Get visual selection using getregion (requires Neovim 0.10+)
  local mode = vim.fn.mode()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local lines = vim.fn.getregion(start_pos, end_pos, { type = mode })

  if not lines or #lines == 0 then
    vim.notify("jeancode: no selection", vim.log.levels.WARN)
    return
  end

  -- Ensure panel is visible
  terminal.ensure_visible()
  local watcher = require("jeancode.watcher")
  watcher.start()

  -- Build context-aware message with file path and line numbers
  local header = ""
  if file ~= "" then
    local relative = vim.fn.fnamemodify(file, ":~:.")
    header = "From " .. relative .. ":" .. start_line .. "-" .. end_line
    if ft ~= "" then
      header = header .. " (" .. ft .. ")"
    end
    header = header .. ":\n"
  end

  local code = table.concat(lines, "\n")
  local text = header .. "```" .. ft .. "\n" .. code .. "\n```\n"
  terminal.send(text)

  -- Exit visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end

return M
