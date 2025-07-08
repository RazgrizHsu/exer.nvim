# exer.nvim

A unified multi-language task executor for Neovim.

## Features

- **Multi-language support** – Run code across multiple languages through a single interface  
- **Unified task management** – Consistent UI for compiling, executing, and testing  
- **Project-aware configuration** – Auto-detects and runs project-specific tasks  
- **Real-time output** – Live output with ANSI color support  
- **Smart navigation** – Smooth window switching between editor and task views  
- **Extensible architecture** – Easily integrate with build tools and test frameworks  

## Requirements

- **Neovim** &gt;= 0.10.0
- A [Nerd Font](https://www.nerdfonts.com/) (for proper icon display)  

## Installation

Install with your favorite package manager:

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- Option 1: Use default keymaps (automatic)
{
  "RazgrizHsu/exer.nvim",
  config = function()
    require("exer").setup({
      debug = false,
      ui = {
        height = 0.3,         -- UI height (0.0-1.0 for percentage, >1 for fixed lines)
        list_width = 36,      -- Task list width (0.0-1.0 for percentage, >1 for fixed columns)
        auto_toggle = true,   -- Auto-open UI when task starts
        auto_scroll = true,   -- Auto-scroll task panel to bottom
      },
    })
  end,
}

-- Option 2: Custom keymaps via keys table
{
  "RazgrizHsu/exer.nvim",
  keys = {
    { "<leader>ro", "<cmd>ExerOpen<cr>", desc = "Open task picker" },
    { "<leader>rr", "<cmd>ExerRedo<cr>", desc = "Re-run last task" },
    { "<leader>rx", "<cmd>ExerStop<cr>", desc = "Stop all running tasks" },
    { "<A-/>", "<cmd>ExerShow<cr>", desc = "Toggle task output window" },
    { "<C-w>t", "<cmd>ExerFocusUI<cr>", desc = "Focus task UI" },
    { "<C-j>", "<cmd>ExerNavDown<cr>", desc = "Smart navigate down" },
    { "<C-k>", "<cmd>ExerNavUp<cr>", desc = "Smart navigate up" },
    { "<C-h>", "<cmd>ExerNavLeft<cr>", desc = "Smart navigate left" },
    { "<C-l>", "<cmd>ExerNavRight<cr>", desc = "Smart navigate right" },
  },
  config = function()
    require("exer").setup({
      debug = false,
      ui = {
        height = 0.4,
        list_width = 40,
        auto_toggle = false,
        auto_scroll = true,
      },
    })
  end,
}

-- Option 3: Disable default keymaps completely
{
  "RazgrizHsu/exer.nvim",
  config = function()
    require("exer").setup({
      disable_default_keymaps = true,
      ui = {
        height = 30,          -- Fixed height: 30 lines
        list_width = 0.25,    -- List width: 25% of editor width
        auto_toggle = true,
        auto_scroll = false,
      },
    })
    -- Set your own keymaps
    vim.keymap.set("n", "<leader>er", "<cmd>ExerOpen<cr>", { desc = "Open exer" })
  end,
}
```

## Configuration Options

### UI Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `height` | `number` | `0.3` | UI height. Values 0.0-1.0 = percentage, >1 = fixed lines |
| `list_width` | `number` | `36` | Task list width. Values 0.0-1.0 = percentage, >1 = fixed columns |
| `auto_toggle` | `boolean` | `true` | Automatically open UI when a task starts |
| `auto_scroll` | `boolean` | `true` | Automatically scroll task panel to show latest output |
| `keymaps` | `table` | See below | Custom keymaps for UI interactions |

#### UI Keymaps

| Key | Default | Description |
|-----|---------|-------------|
| `stop_task` | `'x'` | Stop the selected/current task |
| `clear_completed` | `'c'` | Clear all completed tasks |
| `close_ui` | `'q'` | Close the task UI |
| `toggle_auto_scroll` | `'a'` | Toggle auto-scroll in task panel |

Example:
```lua
require('exer').setup({
  ui = {
    keymaps = {
      stop_task = 's',        -- Use 's' instead of 'x' to stop tasks
      clear_completed = 'd',   -- Use 'd' to clear completed tasks
      close_ui = '<Esc>',     -- Use Escape to close UI
      toggle_auto_scroll = 'a' -- Keep default 'a' for auto-scroll
    }
  }
})
```

### Other Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `debug` | `boolean` | `false` | Enable debug logging |
| `disable_default_keymaps` | `boolean` | `false` | Disable all default keymaps |

## Quick Start

1. Open a source file in Neovim  
2. Press `<leader>ro` to open the task picker  
3. Select a task to execute  
4. View output in the task window  

## Key Bindings

| Key          | Command              | Description                          |
|--------------|----------------------|--------------------------------------|
| `<leader>ro` | `:ExerOpen`          | Open task picker                     |
| `<leader>rr` | `:ExerRedo`          | Re-run the last task                 |
| `<leader>rx` | `:ExerStop`          | Stop all running tasks               |
| `<A-/>`      | `:ExerShow`          | Toggle task output window            |
| `<C-w>t`     | `:ExerFocusUI`       | Focus on task output window          |
| `<C-hjkl>`   | —                    | Navigate between editor and task UI  |


## Development Status

⚠️ **Work in Progress** – This plugin is under active development and subject to change.

Current focus:
- Core execution engine
- Expanding language support
- UI/UX enhancements
- Integration with common build tools

## Developer Notes

> As a long-time JetBrains user transitioning to Neovim, I found no task executor that matched my workflow.  
> Inspired by the amazing plugins from the community, I decided to build one myself — and thus, *exer.nvim* was born.  
> This project is still evolving, and there's much room for improvement.  
> If it ends up helping even just one person, I’d consider it a success.

## Contributing

Contributions are welcome!  
Feel free to open an issue or submit a pull request.

