local M = {}

local config = require("scissors.config").config
local rw = require("scissors.read-write-operations")
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@class (exact) extMarkInfo
---@field bufnr number
---@field ns number
---@field id number

--------------------------------------------------------------------------------

---@param pathOfSnippetFile string
---@return string|false filetype
---@nodiscard
local function guessFileType(pathOfSnippetFile)
	-- primary: read `package.json` https://code.visualstudio.com/api/language-extensions/snippet-guide
	local relPathOfSnipFile = pathOfSnippetFile:sub(#config.snippetDir + 2)
	local packageJson = rw.readAndParseJson(config.snippetDir .. "/package.json")
	local snipFilesInfo = packageJson.contributes.snippets
	local fileMetadata = vim.tbl_filter(
		function(info) return info.path:gsub("^%.?/", "") == relPathOfSnipFile end,
		snipFilesInfo
	)
	if fileMetadata[1] then
		local lang = fileMetadata[1].language
		if type(lang) == "string" then lang = { lang } end
		lang = vim.tbl_filter(function(l) return l ~= "global" and l ~= "all" end, lang)
		if lang[1] then return lang[1] end
	end

	-- fallback #1: filename is filetype
	local filename = vim.fs.basename(pathOfSnippetFile):gsub("%.json$", "")
	local allKnownFts = vim.fn.getcompletion("", "filetype")
	if vim.tbl_contains(allKnownFts, filename) then return filename end

	-- fallback #2: filename is extension
	local matchedFt = vim.filetype.match { filename = "dummy." .. filename }
	if matchedFt then return matchedFt end

	return false
end

---@param snip snippetObj snippet to update/create
---@param prefixBodySep extMarkInfo the extmark representing the horizontal divider, its position marks number of prefixes
---@param editedLines string[]
local function updateSnippetFile(snip, editedLines, prefixBodySep)
	local snippetsInFile = rw.readAndParseJson(snip.fullPath)
	local filepath = snip.fullPath

	-- determine prefix & body
	-- INFO moved separator line position indicates the number of prefixes
	local extM = prefixBodySep
	local numOfPrefixes = vim.api.nvim_buf_get_extmark_by_id(extM.bufnr, extM.ns, extM.id, {})[1] + 1
	local prefix = vim.list_slice(editedLines, 1, numOfPrefixes)
	local body = vim.list_slice(editedLines, numOfPrefixes + 1, #editedLines)

	-- LINT
	-- trim (only trailing for body, since leading there is indentation)
	prefix = vim.tbl_map(function(line) return vim.trim(line) end, prefix)
	body = vim.tbl_map(function(line) return line:gsub("%s+$", "") end, body)
	-- remove deleted prefixes
	prefix = vim.tbl_filter(function(line) return line ~= "" end, prefix)
	-- trim trailing empty lines from body
	while body[#body] == "" do
		vim.notify("🪚 body: " .. vim.inspect(body))
		table.remove(body)
	end
	-- GUARD validate
	if #body == 0 then
		u.notify("Body is empty. No changes made.", "warn")
		return
	end
	if #prefix == 0 then
		u.notify("Prefix is empty. No changes made.", "warn")
		return
	end

	-- new snippet: key = prefix
	local isNewSnippet = snip.originalKey == nil
	local key = isNewSnippet and prefix[1] or snip.originalKey
	assert(key, "Snippet key missing")
	-- ensure key is unique
	while isNewSnippet and snippetsInFile[key] ~= nil do
		key = key .. "_1"
	end

	-- update snipObj
	snip.originalKey = nil -- delete key set by this plugin
	snip.fullPath = nil -- delete key set by this plugin
	snip.body = #body == 1 and body[1] or body
	snip.prefix = #prefix == 1 and prefix[1] or prefix
	snippetsInFile[key] = snip

	-- write & notify
	local success = rw.writeAndFormatSnippetFile(filepath, snippetsInFile)
	if success then
		local displayName = #key > 20 and key:sub(1, 20) .. "…" or key
		local action = isNewSnippet and "created" or "updated"
		u.notify(("%q %s."):format(displayName, action))
	end
end

--------------------------------------------------------------------------------

---@param snip snippetObj
---@param mode "new"|"update"
function M.editInPopup(snip, mode)
	local a = vim.api
	local conf = config.editSnippetPopup

	-- snippet properties
	local body = type(snip.body) == "string" and { snip.body } or snip.body ---@cast body string[]
	local prefix = type(snip.prefix) == "string" and { snip.prefix } or snip.prefix ---@cast prefix string[]
	local numOfPrefixes = #prefix -- needs to be saved as list_extend mutates `prefix`
	local snipLines = vim.list_extend(prefix, body)
	local nameOfSnippetFile = vim.fs.basename(snip.fullPath)

	-- title
	local displayName = mode == "new" and "New Snippet" or snip.originalKey:sub(1, 25)
	local title = mode == "new" and (" New Snippet in %q "):format(nameOfSnippetFile)
		or (" Editing %q [%s] "):format(displayName, nameOfSnippetFile)

	-- create buffer and window
	local bufnr = a.nvim_create_buf(false, true)
	a.nvim_buf_set_lines(bufnr, 0, -1, false, snipLines)
	a.nvim_buf_set_name(bufnr, displayName)
	local guessedFt = guessFileType(snip.fullPath)
	if guessedFt then a.nvim_buf_set_option(bufnr, "filetype", guessedFt) end
	a.nvim_buf_set_option(bufnr, "buftype", "nofile")

	local winnr = a.nvim_open_win(bufnr, true, {
		relative = "win",
		title = title,
		title_pos = "center",
		border = conf.border,
		-- centered window
		width = math.floor(conf.width * a.nvim_win_get_width(0)),
		height = math.floor(conf.height * a.nvim_win_get_height(0)),
		row = math.floor((1 - conf.height) * a.nvim_win_get_height(0) / 2),
		col = math.floor((1 - conf.width) * a.nvim_win_get_width(0) / 2),
		zindex = 1, -- below nvim-notify floats
	})
	a.nvim_win_set_option(winnr, "signcolumn", "no")

	-- move cursor
	if mode == "new" then
		vim.cmd.startinsert()
	elseif mode == "update" then
		local firstLineOfBody = numOfPrefixes + 1
		pcall(a.nvim_win_set_cursor, winnr, { firstLineOfBody, 0 })
	end

	-- highlight cursor positions like `$0` or `${1:foo}`
	vim.fn.matchadd("DiagnosticVirtualTextInfo", [[\$\d]])
	vim.fn.matchadd("DiagnosticVirtualTextInfo", [[\${\d:.\{-}}]])

	-- highlight prefix lines and add label
	local ns = a.nvim_create_namespace("nvim-scissors")
	for i = 1, numOfPrefixes do
		local ln = i - 1
		local label = numOfPrefixes == 1 and "Prefix" or "Prefix #" .. i
		a.nvim_buf_add_highlight(bufnr, ns, "DiagnosticVirtualTextHint", ln, 0, -1)
		a.nvim_buf_set_extmark(bufnr, ns, ln, 0, {
			virt_text = { { label, "Todo" } },
			virt_text_pos = "right_align",
		})
	end
	-- prefixBodySeparator -> INFO its position determines number of prefixes
	local winWidth = a.nvim_win_get_width(winnr)
	local prefixBodySep = { bufnr = bufnr, ns = ns, id = -1 } ---@type extMarkInfo
	prefixBodySep.id = a.nvim_buf_set_extmark(bufnr, ns, numOfPrefixes - 1, 0, {
		virt_lines = {
			{ { ("═"):rep(winWidth), "FloatBorder" } },
		},
		virt_lines_leftcol = true,
	})

	-- keymaps
	local function close()
		a.nvim_win_close(winnr, true)
		a.nvim_buf_delete(bufnr, { force = true })
	end
	local opts = { buffer = bufnr, nowait = true, silent = true }
	vim.keymap.set("n", conf.keymaps.cancel, close, opts)
	vim.keymap.set("n", conf.keymaps.saveChanges, function()
		local editedLines = a.nvim_buf_get_lines(bufnr, 0, -1, false)
		updateSnippetFile(snip, editedLines, prefixBodySep)
		close()
	end, opts)
	vim.keymap.set("n", conf.keymaps.delete, function()
		if mode == "new" then
			u.notify("Cannot delete a snippet that has not been saved yet.", "warn")
			return
		end
		rw.deleteSnippet(snip)
		close()
	end, opts)
	vim.keymap.set("n", conf.keymaps.openInFile, function()
		close()
		local locationInFile = snip.originalKey:gsub(" ", [[\ ]])
		vim.cmd(("edit +/%q %s"):format(locationInFile, snip.fullPath))
	end, opts)
end

--------------------------------------------------------------------------------
return M
