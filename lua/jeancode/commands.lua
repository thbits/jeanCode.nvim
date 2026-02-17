local M = {}

function M.setup()
  vim.api.nvim_create_user_command("JeanCode", function()
    require("jeancode").toggle()
  end, { desc = "Toggle Claude Code panel" })

  vim.api.nvim_create_user_command("JeanCodeNew", function()
    require("jeancode").new_session()
  end, { desc = "Start new Claude Code session" })

  vim.api.nvim_create_user_command("JeanCodeSend", function()
    require("jeancode").send_selection()
  end, { range = true, desc = "Send visual selection to Claude Code" })

  vim.api.nvim_create_user_command("JeanCodeContext", function()
    require("jeancode.terminal").write_buffers_file()
    vim.notify("jeancode: buffers file updated", vim.log.levels.INFO)
  end, { desc = "Update .jeancode_buffers file" })
end

return M
