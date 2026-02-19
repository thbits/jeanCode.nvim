local M = {}

local function reopen(state, config, window, position)
  config.options.window.position = position
  window.close(state.win_id)
  state.win_id = window.open(state.bufnr, config.options.window)
  if config.options.window.enter_insert then
    vim.cmd("startinsert")
  end
end

function M.toggle()
  local config = require("jeancode.config")
  local terminal = require("jeancode.terminal")
  local window = require("jeancode.window")
  local state = terminal.get_state()

  -- Cycle position: right -> bottom -> left -> float -> right
  local cycle = { right = "bottom", bottom = "left", left = "float", float = "right" }
  local cur = config.options.window.position
  local next_pos = cycle[cur] or "right"

  if not window.is_visible(state.win_id) then
    -- Panel is closed — open it in the next layout
    config.options.window.position = next_pos
    if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
      state.win_id = window.open(state.bufnr, config.options.window)
      if config.options.window.enter_insert then
        vim.cmd("startinsert")
      end
    else
      terminal.spawn()
    end
  else
    reopen(state, config, window, next_pos)
  end
  vim.notify("jeancode: layout → " .. next_pos, vim.log.levels.INFO)
end

function M.float()
  local config = require("jeancode.config")
  local terminal = require("jeancode.terminal")
  local window = require("jeancode.window")
  local state = terminal.get_state()

  if not window.is_visible(state.win_id) then
    -- Panel is hidden — open it as float
    if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
      reopen(state, config, window, "float")
    else
      -- No session yet, spawn one
      config.options.window.position = "float"
      terminal.spawn()
    end
  elseif config.options.window.position == "float" then
    -- Already floating — close it
    window.close(state.win_id)
    state.win_id = nil
  else
    -- Visible in a split — switch to float
    reopen(state, config, window, "float")
  end
end

return M
