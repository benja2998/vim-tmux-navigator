-- Guard against multiple loads or unsupported versions
if vim.g.loaded_tmux_navigator or vim.fn.has("nvim-0.5") == 0 then
    return
end
vim.g.loaded_tmux_navigator = 1

local M = {}

-- Helper: Navigate in Vim
local function vim_navigate(direction)
    local ok, _ = pcall(vim.cmd, "wincmd " .. direction)
    if not ok then
        vim.api.nvim_echo({{"Cannot move in direction: " .. direction, "ErrorMsg"}}, false, {})
    end
end

-- Detect if running in FZF terminal
local function is_fzf()
    return vim.bo.filetype == "fzf"
end

-- Detect tmux executable (tmux or tmate)
local function tmux_executable()
    if string.find(vim.env.TMUX or "", "tmate") then
        return "tmate"
    else
        return "tmux"
    end
end

-- Get tmux socket from $TMUX
local function tmux_socket()
    local tmux_env = vim.env.TMUX or ""
    return vim.split(tmux_env, ",")[1] or ""
end

-- Run a tmux command
local function tmux_cmd(cmd)
    local full_cmd = tmux_executable() .. " -S " .. tmux_socket() .. " " .. cmd
    return vim.fn.system(full_cmd)
end

-- Check if current tmux pane is zoomed
local function tmux_pane_zoomed()
    return tonumber(tmux_cmd("display-message -p '#{window_zoomed_flag}'")) == 1
end

-- Map Vim directions to tmux flags
local pane_dir = { h = "L", j = "D", k = "U", l = "R", p = "p" }

-- State: last tmux pane
local tmux_is_last_pane = false

-- Should forward navigation to tmux
local function should_forward(tmux_last_pane, at_tab_edge)
    if vim.g.tmux_navigator_disable_when_zoomed == 1 and tmux_pane_zoomed() then
        return false
    end
    return tmux_last_pane or at_tab_edge
end

-- Main navigation function
function M.navigate(direction)
    local nr = vim.fn.winnr()
    local tmux_last_pane = (direction == "p" and tmux_is_last_pane)

    if not tmux_last_pane then
        vim_navigate(direction)
    end

    local at_tab_edge = (nr == vim.fn.winnr())

    if should_forward(tmux_last_pane, at_tab_edge) then
        -- Save buffers if requested
        if vim.g.tmux_navigator_save_on_switch == 1 then
            pcall(vim.cmd, "update")
        elseif vim.g.tmux_navigator_save_on_switch == 2 then
            pcall(vim.cmd, "wall")
        end

        local args = "select-pane -t " .. vim.fn.shellescape(vim.env.TMUX_PANE) .. " -" .. pane_dir[direction]

        if vim.g.tmux_navigator_preserve_zoom == 1 then
            args = args .. " -Z"
        end

        if vim.g.tmux_navigator_no_wrap == 1 and direction ~= "p" then
            local pos = { h = "left", j = "bottom", k = "top", l = "right" }
            args = string.format('if -F "#{pane_at_%s}" "" "%s"', pos[direction], args)
        end

        vim.fn.system(tmux_executable() .. " -S " .. tmux_socket() .. " " .. args)
        tmux_is_last_pane = true
    else
        tmux_is_last_pane = false
    end
end

-- Key mappings
local function map_keys()
    local opts = { noremap = true, silent = true }

    vim.keymap.set("n", "<C-h>", function() M.navigate("h") end, opts)
    vim.keymap.set("n", "<C-j>", function() M.navigate("j") end, opts)
    vim.keymap.set("n", "<C-k>", function() M.navigate("k") end, opts)
    vim.keymap.set("n", "<C-l>", function() M.navigate("l") end, opts)
    vim.keymap.set("n", "<C-\\>", function() M.navigate("p") end, opts)

    if vim.env.TMUX then
        vim.keymap.set("t", "<C-h>", function() if is_fzf() then return "<C-h>" else M.navigate("h") end end, { expr = true, silent = true })
        vim.keymap.set("t", "<C-j>", function() if is_fzf() then return "<C-j>" else M.navigate("j") end end, { expr = true, silent = true })
        vim.keymap.set("t", "<C-k>", function() if is_fzf() then return "<C-k>" else M.navigate("k") end end, { expr = true, silent = true })
        vim.keymap.set("t", "<C-l>", function() if is_fzf() then return "<C-l>" else M.navigate("l") end end, { expr = true, silent = true })
    end
end

map_keys()
return M
