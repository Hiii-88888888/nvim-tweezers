local M = {}
local u = require("tweezers.utils")
--------------------------------------------------------------------------------

local hasNotifiedOnRestartRequirement = false

---@param path string
---@param fileIsNew? boolean
function M.reloadSnippetFile(path, fileIsNew)
	local success = false
	---@type string?
	local errorMsg = ""

	local luasnipInstalled, luasnipLoaders = pcall(require, "luasnip.loaders")
	local nvimSnippetsInstalled, snippetUtils = pcall(require, "snippets.utils")
	local vimVsnipInstalled = vim.g.loaded_vsnip ~= nil -- https://github.com/hrsh7th/vim-vsnip/blob/master/plugin/vsnip.vim#L4C5-L4C17
	local blinkCmpInstalled, blinkCmp = pcall(require, "blink.cmp")
	local basicsLsInstalled = vim.fn.executable("basics-language-server") == 1
	local miniSnippetsInstalled = _G.MiniSnippets ~= nil ---@diagnostic disable-line:undefined-field
	-- INFO yasp.nvim does not need to be hot-reloaded, since it reloads every
	-- time on `BufEnter` https://github.com/DimitrisDimitropoulos/yasp.nvim/issues/2#issuecomment-2764463329

	-----------------------------------------------------------------------------

	-- GUARD
	-- hot-reloading new files is supported by mini.snippets: https://github.com/chrisgrieser/nvim-scissors/pull/25#issuecomment-2561345395
	if fileIsNew and not miniSnippetsInstalled then
		local name = vim.fs.basename(path)
		local msg = ("%q is a new file and thus cannot be hot-reloaded. "):format(name)
			.. "Please restart nvim for this change to take effect."
		u.notify(msg)
		return
	end

	-----------------------------------------------------------------------------
	-- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
	if luasnipInstalled then
		success, errorMsg = pcall(luasnipLoaders.reload_file, path)

	-- undocumented, https://github.com/garymjr/nvim-snippets/blob/main/lua/snippets/utils/init.lua#L161-L178
	elseif nvimSnippetsInstalled then
		success, errorMsg = pcall(snippetUtils.reload_file, path, true)

	-- https://github.com/hrsh7th/vim-vsnip/blob/02a8e79295c9733434aab4e0e2b8c4b7cea9f3a9/autoload/vsnip/source/vscode.vim#L7
	elseif vimVsnipInstalled then
		success, errorMsg = pcall(vim.fn["vsnip#source#vscode#refresh"], path)

	-- https://github.com/antonk52/basics-language-server/issues/1
	elseif basicsLsInstalled then
		local client = vim.lsp.get_clients({ name = "basics_ls" })[1]
		if client then
			success = true
			client:stop()
			vim.defer_fn(vim.cmd.edit, 1000) -- wait for shutdown -> reloads -> re-attach LSPs
		else
			success = false
			errorMsg = "`basics_ls` client not found."
		end

	-- https://github.com/Saghen/blink.cmp/issues/428#issuecomment-2513235377
	elseif blinkCmpInstalled then
		success, errorMsg = pcall(blinkCmp.reload, "snippets")

	-- contributed by @echasnovski themselves via #25
	elseif miniSnippetsInstalled then
		--- Reset whole cache so that next "prepare" step rereads file(s)
		_G.MiniSnippets.setup(_G.MiniSnippets.config) ---@diagnostic disable-line:undefined-field
		success = true

	-----------------------------------------------------------------------------

	-- NOTIFY
	elseif not hasNotifiedOnRestartRequirement then
		local msg =
			"Your snippet plugin does not support hot-reloading. Restart nvim for changes to take effect."
		u.notify(msg, "info")
		hasNotifiedOnRestartRequirement = true
		return
	end

	if not success then
		local msg = ("Failed to hot-reload snippet file: %q\n\n."):format(errorMsg)
			.. "Please restart nvim for changes to snippets to take effect. "
			.. "If this issue keeps occurring, create a bug report at your snippet plugin's repo."
		u.notify(msg, "warn")
	end
end

--------------------------------------------------------------------------------
return M
