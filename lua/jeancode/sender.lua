local M = {}

function M.send_selection()
  local terminal = require("jeancode.terminal")
  local config = require("jeancode.config")

  -- Capture file context BEFORE any window changes
  local file = vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype

  -- Get visual selection using getregion (requires Neovim 0.10+)
  local mode = vim.fn.visualmode()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]
  local lines = vim.fn.getregion(start_pos, end_pos, { type = mode })

  if not lines or #lines == 0 then
    vim.notify("jeancode: no selection", vim.log.levels.WARN)
    return
  end

  -- Ensure panel is visible
  terminal.ensure_visible()
  local watcher = require("jeancode.watcher")
  watcher.start()

  local relative = file ~= "" and vim.fn.fnamemodify(file, ":~:.") or "unknown"
  local ft_info = ft ~= "" and (" (" .. ft .. ")") or ""
  local send_mode = config.options.send_mode

  local text
  if send_mode == "reference" then
    -- Send just file path + line/col range (saves tokens, Claude reads the file)
    local range
    if mode == "V" or (start_line == end_line and start_col == 1 and end_col >= #lines[#lines]) then
      -- Full line selection
      if start_line == end_line then
        range = "line " .. start_line
      else
        range = "lines " .. start_line .. "-" .. end_line
      end
    else
      -- Character-level selection
      if start_line == end_line then
        range = "line " .. start_line .. ", columns " .. start_col .. "-" .. end_col
      else
        range = "line " .. start_line .. " col " .. start_col .. " to line " .. end_line .. " col " .. end_col
      end
    end
    text = "See " .. relative .. ", " .. range .. ft_info
      .. ". Read the file at those positions and work with that code.\n"
  else
    -- Send full content (original behavior)
    local header = "From " .. relative .. ":" .. start_line .. "-" .. end_line .. ft_info .. ":\n"
    local code = table.concat(lines, "\n")
    text = header .. "```" .. ft .. "\n" .. code .. "\n```\n"
  end

  terminal.send(text)
end

return M
