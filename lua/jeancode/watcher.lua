local config = require("jeancode.config")

local M = {}

local timer = nil
local augroup = nil
local saved_updatetime = nil

function M.setup()
  augroup = vim.api.nvim_create_augroup("JeanCodeWatcher", { clear = true })

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = augroup,
    pattern = "*",
    callback = function()
      if vim.fn.getcmdwintype() == "" then
        vim.cmd("checktime")
      end
    end,
  })

  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = augroup,
    pattern = "*",
    callback = function()
      local cfg = config.options
      if cfg.refresh.show_notifications then
        vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.INFO)
      end
    end,
  })

end

function M.start()
  local cfg = config.options
  if not cfg.refresh.enable then
    return
  end

  -- Save and reduce updatetime for faster CursorHold triggers
  saved_updatetime = vim.o.updatetime
  vim.o.updatetime = cfg.refresh.updatetime

  -- Start polling timer
  if not timer then
    timer = vim.uv.new_timer()
    timer:start(
      cfg.refresh.timer_interval,
      cfg.refresh.timer_interval,
      vim.schedule_wrap(function()
        if vim.fn.getcmdwintype() == "" then
          vim.cmd("checktime")
        end
      end)
    )
  end
end

function M.stop()
  -- Restore updatetime
  if saved_updatetime then
    vim.o.updatetime = saved_updatetime
    saved_updatetime = nil
  end

  -- Stop timer
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

return M
