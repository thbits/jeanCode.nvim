local config = require("jeancode.config")
local git = require("jeancode.git")
local window = require("jeancode.window")

local M = {}

local state = {
  bufnr = nil,
  chan_id = nil,
  win_id = nil,
  session_id = nil, -- Claude session UUID, persists across respawns
  source_bufnr = nil, -- last non-terminal buffer the user was in
  buffers_file = nil, -- path to .jeancode_buffers file
  user_closed = false, -- true when user explicitly toggled off (don't auto-reopen)
}

local function is_buf_valid()
  return state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)
end

local function clean_state()
  state.bufnr = nil
  state.chan_id = nil
  state.win_id = nil
  -- NOTE: session_id, source_bufnr, buffers_file are NOT cleared here
end

local function generate_uuid()
  -- Try system uuidgen first
  local result = vim.fn.systemlist("uuidgen")
  if vim.v.shell_error == 0 and result[1] then
    return result[1]:lower()
  end
  -- Fallback: generate a v4 UUID in Lua
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return (template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end))
end

--- Write the current list of open buffers to .jeancode_buffers file.
--- Claude reads this file to stay aware of what's open in Neovim.
function M.write_buffers_file()
  if not state.buffers_file then return end
  local bufs = vim.api.nvim_list_bufs()
  local lines = {}
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.bo[buf].buftype == "" then
        local ft = vim.bo[buf].filetype
        local marker = (buf == state.source_bufnr) and " (active)" or ""
        local ft_info = (ft ~= "") and (" [" .. ft .. "]") or ""
        table.insert(lines, name .. ft_info .. marker)
      end
    end
  end
  local f = io.open(state.buffers_file, "w")
  if f then
    f:write("Currently open files in Neovim:\n")
    for _, line in ipairs(lines) do
      f:write("  - " .. line .. "\n")
    end
    f:close()
  end
end

function M.spawn(source_bufnr, opts)
  opts = opts or {}
  local cfg = config.options
  local cmd = cfg.command

  if vim.fn.executable(cmd) ~= 1 then
    vim.notify("jeancode: '" .. cmd .. "' not found in PATH", vim.log.levels.ERROR)
    return
  end

  -- Capture context from the source buffer BEFORE opening the terminal window
  source_bufnr = source_bufnr or state.source_bufnr or vim.api.nvim_get_current_buf()
  state.source_bufnr = source_bufnr
  local source_file = vim.api.nvim_buf_get_name(source_bufnr)

  -- Create a buffer with bufhidden=hide for session persistence
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })

  -- Open window first so termopen runs in it
  state.win_id = window.open(bufnr, cfg.window)

  -- Determine cwd: use git root of the current file, or the file's directory
  local cwd = nil
  if cfg.git.auto_detect_root then
    cwd = git.get_root(source_file ~= "" and source_file or nil)
  else
    cwd = source_file ~= "" and vim.fn.fnamemodify(source_file, ":h") or vim.fn.getcwd()
  end

  -- Write buffers file and build command
  state.buffers_file = cwd .. "/.jeancode_buffers"
  M.write_buffers_file()

  local spawn_cmd = cmd
  if cfg.cli.args and #cfg.cli.args > 0 then
    spawn_cmd = spawn_cmd .. " " .. table.concat(cfg.cli.args, " ")
  end
  -- Session tracking: resume existing or start new with known ID
  if opts.resume and state.session_id then
    spawn_cmd = spawn_cmd .. " --resume " .. state.session_id
  else
    state.session_id = generate_uuid()
    spawn_cmd = spawn_cmd .. " --session-id " .. state.session_id
  end
  -- Tell Claude to read .jeancode_buffers for live context
  local prompt = "The file " .. state.buffers_file
    .. " contains the list of currently open files in Neovim. "
    .. "Read this file before each response to stay aware of the user's open buffers. "
    .. "The file is kept up to date automatically."
  prompt = prompt:gsub("'", "'\\''")
  spawn_cmd = spawn_cmd .. " --append-system-prompt '" .. prompt .. "'"

  -- Spawn terminal
  state.bufnr = bufnr
  state.chan_id = vim.fn.termopen(spawn_cmd, {
    cwd = cwd,
    on_exit = function(_, exit_code, _)
      local exited_bufnr = bufnr
      vim.schedule(function()
        if state.bufnr == exited_bufnr then
          if vim.api.nvim_buf_is_valid(exited_bufnr) then
            vim.api.nvim_buf_delete(exited_bufnr, { force = true })
          end
          clean_state()
        else
          if vim.api.nvim_buf_is_valid(exited_bufnr) then
            pcall(vim.api.nvim_buf_delete, exited_bufnr, { force = true })
          end
        end
      end)
    end,
  })

  -- Set up terminal-local keymaps for window navigation
  M._setup_terminal_keymaps(bufnr)

  -- Auto-update context when user navigates to this pane
  M._setup_context_watcher(bufnr)

  if cfg.window.enter_insert then
    vim.cmd("startinsert")
  end
end

function M._setup_terminal_keymaps(bufnr)
  local opts = { buffer = bufnr, noremap = true, silent = true }
  -- Allow <C-w> window navigation from terminal mode
  vim.keymap.set("t", "<C-w>h", "<C-\\><C-n><C-w>h", opts)
  vim.keymap.set("t", "<C-w>j", "<C-\\><C-n><C-w>j", opts)
  vim.keymap.set("t", "<C-w>k", "<C-\\><C-n><C-w>k", opts)
  vim.keymap.set("t", "<C-w>l", "<C-\\><C-n><C-w>l", opts)
  vim.keymap.set("t", "<C-w><C-w>", "<C-\\><C-n><C-w><C-w>", opts)

  -- Support vim-tmux-navigator style <C-h/j/k/l> navigation
  local nav_cmds = {
    ["<C-h>"] = "TmuxNavigateLeft",
    ["<C-j>"] = "TmuxNavigateDown",
    ["<C-k>"] = "TmuxNavigateUp",
    ["<C-l>"] = "TmuxNavigateRight",
  }
  for key, cmd in pairs(nav_cmds) do
    vim.keymap.set("t", key, function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
      vim.schedule(function()
        if vim.fn.exists(":" .. cmd) == 2 then
          vim.cmd(cmd)
        else
          vim.cmd("wincmd " .. key:sub(-1):lower())
        end
      end)
    end, opts)
  end
end

local context_watcher_group = vim.api.nvim_create_augroup("jeancode_context_watcher", { clear = true })

function M._setup_context_watcher(bufnr)
  -- Track the last non-terminal buffer and update .jeancode_buffers on every buffer change
  vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufDelete" }, {
    group = context_watcher_group,
    callback = function(ev)
      -- Track active non-terminal buffer
      if ev.event == "BufEnter" and vim.bo[ev.buf].buftype == "" and ev.buf ~= state.bufnr then
        state.source_bufnr = ev.buf
      end
      -- Update the file on disk so Claude always has current info
      M.write_buffers_file()
    end,
  })

  -- Auto enter insert mode when focusing the terminal pane
  vim.api.nvim_create_autocmd("BufEnter", {
    group = context_watcher_group,
    buffer = bufnr,
    callback = function()
      if config.options.window.enter_insert then
        vim.cmd("startinsert")
      end
    end,
  })

  -- Reopen the Claude window if something else closes it (e.g., file explorer sidebar)
  vim.api.nvim_create_autocmd("WinClosed", {
    group = context_watcher_group,
    callback = function(ev)
      local closed_win = tonumber(ev.match)
      if closed_win == state.win_id and is_buf_valid() then
        state.win_id = nil
        -- Only reopen if the user didn't explicitly close it via toggle
        if not state.user_closed then
          vim.schedule(function()
            if is_buf_valid() and not window.is_visible(state.win_id) then
              local cfg = config.options
              state.win_id = window.open(state.bufnr, cfg.window)
            end
          end)
        end
      end
    end,
  })
end

function M.toggle(source_bufnr)
  -- Window is visible -> close it (keep buffer alive)
  if window.is_visible(state.win_id) then
    state.user_closed = true
    window.close(state.win_id)
    state.win_id = nil
    return
  end

  source_bufnr = source_bufnr or vim.api.nvim_get_current_buf()
  state.source_bufnr = source_bufnr
  state.user_closed = false

  -- Buffer exists but window is hidden -> reopen the window
  if is_buf_valid() then
    local cfg = config.options
    state.win_id = window.open(state.bufnr, cfg.window)
    if cfg.window.enter_insert then
      vim.cmd("startinsert")
    end
    return
  end

  -- No session -> spawn fresh
  M.spawn(source_bufnr)
end

function M.destroy()
  -- Clear autocmds before destroying buffer to prevent re-entry
  vim.api.nvim_clear_autocmds({ group = context_watcher_group })
  if is_buf_valid() then
    if state.chan_id then
      pcall(vim.fn.jobstop, state.chan_id)
    end
    pcall(vim.api.nvim_buf_delete, state.bufnr, { force = true })
  end
  if window.is_visible(state.win_id) then
    window.close(state.win_id)
  end
  -- Clean up the buffers file
  if state.buffers_file then
    os.remove(state.buffers_file)
  end
  clean_state()
end

function M.new_session()
  M.destroy()
  state.session_id = nil -- clear so spawn generates a fresh session
  M.spawn()
end

function M.send(text)
  if not state.chan_id then
    vim.notify("jeancode: no active session", vim.log.levels.WARN)
    return
  end
  vim.fn.chansend(state.chan_id, text)
end

function M.ensure_visible()
  if not window.is_visible(state.win_id) then
    if is_buf_valid() then
      local cfg = config.options
      state.win_id = window.open(state.bufnr, cfg.window)
    else
      M.spawn()
    end
  end
end

function M.get_state()
  return state
end

return M
