if vim.g.loaded_jeancode then
  return
end
vim.g.loaded_jeancode = true

-- Command stubs for lazy.nvim discovery (before setup() is called)
-- These will be overwritten by commands.lua when setup() runs
vim.api.nvim_create_user_command("JeanCode", function()
  require("jeancode").setup({})
  require("jeancode").toggle()
end, { desc = "Toggle Claude Code panel" })

vim.api.nvim_create_user_command("JeanCodeNew", function()
  require("jeancode").setup({})
  require("jeancode").new_session()
end, { desc = "Start new Claude Code session" })

vim.api.nvim_create_user_command("JeanCodeSend", function()
  require("jeancode").setup({})
  require("jeancode").send_selection()
end, { range = true, desc = "Send visual selection to Claude Code" })
