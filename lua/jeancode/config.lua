local M = {}

M.defaults = {
  command = "claude",
  window = {
    position = "right",
    width = 0.30,
    height = 0.30,
    float = { width = 0.8, height = 0.8, border = "rounded" },
    enter_insert = true,
    hide_numbers = true,
    hide_signcolumn = true,
  },
  send_mode = "reference", -- "reference" (file path + line/col range) or "content" (full code block)
  cli = {
    args = {},  -- Extra CLI arguments, e.g. {"--dangerously-skip-permissions", "--verbose"}
  },
  git = { auto_detect_root = true },
  refresh = {
    enable = true,
    updatetime = 100,
    timer_interval = 1000,
    show_notifications = true,
  },
  keymaps = {
    toggle = "<leader>cc",
    send = "<leader>cs",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
