local M = {}

local function apply_win_opts(win_id, cfg)
  if not vim.api.nvim_win_is_valid(win_id) then return end
  if cfg.hide_numbers then
    vim.api.nvim_set_option_value("number", false, { win = win_id })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win_id })
  end
  if cfg.hide_signcolumn then
    vim.api.nvim_set_option_value("signcolumn", "no", { win = win_id })
  end
  -- Lock window size so sidebars/other splits don't shrink it
  if cfg.position == "right" or cfg.position == "left" then
    vim.api.nvim_set_option_value("winfixwidth", true, { win = win_id })
  elseif cfg.position == "bottom" then
    vim.api.nvim_set_option_value("winfixheight", true, { win = win_id })
  end
end

local function open_split(bufnr, cfg)
  local position = cfg.position
  local width = math.floor(vim.o.columns * cfg.width)
  local height = math.floor(vim.o.lines * cfg.height)

  if position == "right" then
    vim.cmd("botright vertical " .. width .. "split")
  elseif position == "left" then
    vim.cmd("topleft vertical " .. width .. "split")
  elseif position == "bottom" then
    vim.cmd("botright " .. height .. "split")
  end

  local win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win_id, bufnr)
  return win_id
end

local function open_float(bufnr, cfg)
  local float_cfg = cfg.float
  local width = math.floor(vim.o.columns * float_cfg.width)
  local height = math.floor(vim.o.lines * float_cfg.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_id = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = float_cfg.border,
  })
  return win_id
end

function M.open(bufnr, cfg)
  local win_id
  if cfg.position == "float" then
    win_id = open_float(bufnr, cfg)
  else
    win_id = open_split(bufnr, cfg)
  end
  apply_win_opts(win_id, cfg)
  return win_id
end

function M.is_visible(win_id)
  return win_id ~= nil and vim.api.nvim_win_is_valid(win_id)
end

function M.close(win_id)
  if not M.is_visible(win_id) then return end
  -- Don't close the last window; switch to an empty buffer instead
  if #vim.api.nvim_list_wins() <= 1 then
    vim.cmd("enew")
  else
    vim.api.nvim_win_close(win_id, true)
  end
end

return M
