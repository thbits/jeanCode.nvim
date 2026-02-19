# jeanCode.nvim

> **Warning:** This is a vibe coding project. Built entirely through conversation with Claude Code. It works, but expect rough edges. PRs welcome.

A Neovim plugin that integrates [Claude Code](https://docs.anthropic.com/en/docs/claude-code) directly into your editor as a side panel. Zero dependencies.

## Features

- Toggle Claude Code in a split or floating window with a single keypress
- Automatic git root detection for project-aware sessions
- Context awareness via `.jeancode_buffers` file — Claude always knows what files you have open
- Session persistence — hide and reshow the panel without losing your conversation
- Automatic file reloading when Claude edits your code
- Send visual selections directly to Claude with file path and line numbers
- Window navigation with `<C-w>` and vim-tmux-navigator support
- Auto insert mode when focusing the Claude panel

## Requirements

- Neovim >= 0.10
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and available in PATH

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "thbits/jeanCode.nvim",
  cmd = { "JeanCode", "JeanCodeNew", "JeanCodeSend", "JeanCodeLayout" },
  keys = {
    { "<leader>cc", "<cmd>JeanCode<cr>", desc = "Toggle Claude Code" },
    { "<leader>cs", "<cmd>JeanCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    { "<leader>cl", "<cmd>JeanCodeLayout<cr>", desc = "Toggle Claude layout" },
  },
  opts = {},
  config = function(_, opts)
    require("jeancode").setup(opts)
  end,
}
```

### Local development

```lua
{
  "thbits/jeanCode.nvim",
  dir = "~/path/to/jeanCode.nvim",
  cmd = { "JeanCode", "JeanCodeNew", "JeanCodeSend", "JeanCodeLayout" },
  keys = {
    { "<leader>cc", "<cmd>JeanCode<cr>", desc = "Toggle Claude Code" },
    { "<leader>cs", "<cmd>JeanCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    { "<leader>cl", "<cmd>JeanCodeLayout<cr>", desc = "Toggle Claude layout" },
  },
  opts = {},
  config = function(_, opts)
    require("jeancode").setup(opts)
  end,
}
```

## Configuration

Below is the full default configuration:

```lua
require("jeancode").setup({
  -- The CLI command to run
  command = "claude",

  -- Window appearance and behavior
  window = {
    position = "right",      -- "right", "left", "bottom", or "float"
    width = 0.30,            -- Width as fraction of screen (for "right"/"left")
    height = 0.30,           -- Height as fraction of screen (for "bottom")
    float = {                -- Floating window options (for "float")
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
    enter_insert = true,     -- Auto enter insert mode in the Claude panel
    hide_numbers = true,     -- Hide line numbers in the Claude panel
    hide_signcolumn = true,  -- Hide the sign column in the Claude panel
  },

  -- Extra CLI arguments passed to the claude command
  cli = {
    args = {},  -- e.g. {"--dangerously-skip-permissions", "--verbose"}
  },

  -- Git integration
  git = {
    auto_detect_root = true,  -- Set cwd to git root of the current file
  },

  -- File watching (auto-reload when Claude edits files)
  refresh = {
    enable = true,
    updatetime = 100,          -- Reduced updatetime while Claude is active
    timer_interval = 1000,     -- Polling interval in ms
    show_notifications = true, -- Show "Buffer reloaded" notifications
  },

  -- Default keymaps (set to false to disable)
  keymaps = {
    toggle = "<leader>cc",  -- Toggle the Claude panel
    send = "<leader>cs",    -- Send visual selection to Claude
  },
})
```

## Configuration Examples

### Right side panel (default)

```lua
opts = {
  window = { position = "right", width = 0.30 },
}
```

### Bottom horizontal split

```lua
opts = {
  window = { position = "bottom", height = 0.40 },
}
```

### Left side panel

```lua
opts = {
  window = { position = "left", width = 0.25 },
}
```

### Floating window

```lua
opts = {
  window = {
    position = "float",
    float = { width = 0.8, height = 0.8, border = "rounded" },
  },
}
```

### Skip permissions (auto-accept mode)

```lua
opts = {
  cli = { args = { "--dangerously-skip-permissions" } },
}
```

### Multiple CLI flags

```lua
opts = {
  cli = { args = { "--dangerously-skip-permissions", "--verbose" } },
}
```

### Custom keymaps

```lua
opts = {
  keymaps = {
    toggle = "<C-,>",
    send = "<leader>cs",
  },
}
```

### Disable default keymaps

```lua
opts = {
  keymaps = {
    toggle = false,
    send = false,
  },
}
```

Then map manually:

```lua
vim.keymap.set("n", "<leader>cc", "<Plug>(jeancode-toggle)")
vim.keymap.set("v", "<leader>cs", "<Plug>(jeancode-send)")
```

## Commands

| Command | Description |
|---|---|
| `:JeanCode` | Toggle the Claude Code panel |
| `:JeanCodeNew` | Start a fresh Claude session |
| `:JeanCodeSend` | Send visual selection to Claude (use in visual mode) |
| `:JeanCodeLayout` | Cycle panel position: right → bottom → left → right |
| `:JeanCodeContext` | Force update the `.jeancode_buffers` file |

## How It Works

### Terminal Management

The plugin uses `vim.fn.termopen()` to run Claude Code in a Neovim terminal buffer. The buffer is created with `bufhidden=hide` so Claude keeps running when you toggle the panel off.

### Context Awareness

When Claude starts, the plugin tells it (via `--append-system-prompt`) to read a `.jeancode_buffers_<pid>` file in `/tmp`. This file is automatically updated whenever you open or close buffers in Neovim. Claude reads it before each response to know what files you're working on. Each Neovim instance gets its own file (keyed by PID), so multiple instances don't conflict. Stale files from dead Neovim instances are cleaned up automatically.

### Session Persistence

Each session gets a UUID. Toggling the panel off/on preserves the conversation. Use `:JeanCodeNew` to start a completely fresh session.

### File Watching

When Claude edits files on disk, the plugin detects changes and auto-reloads affected buffers. This uses a combination of `checktime` polling and `FileChangedShellPost` autocmds.

## Navigation

From the Claude terminal panel:

| Key | Action |
|---|---|
| `<C-w>h/j/k/l` | Navigate to adjacent windows |
| `<C-h/j/k/l>` | vim-tmux-navigator support (if installed) |
| `<leader>cc` | Toggle panel off (works from terminal mode) |

## License

MIT
