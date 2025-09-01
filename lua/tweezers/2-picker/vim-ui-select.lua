local M = {}

local edit = require("tweezers.3-edit-popup")
local u = require("tweezers.utils")
--------------------------------------------------------------------------------

---@param snippets Tweezers.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	vim.ui.select(snippets, {
		prompt = prompt,
		format_item = function(snip)
			local filename = vim.fs.basename(snip.fullPath):gsub("%.lua$", "")
			return u.snipDisplayName(snip) .. " [" .. filename .. "]"
		end,
	}, function(snip)
		if not snip then return end
		edit.editInPopup(snip, "update")
	end)
end

--------------------------------------------------------------------------------

---@param allSnipFiles Tweezers.snipFile[]
---@param bodyPrefill string[] for the new snippet
function M.addSnippet(allSnipFiles, bodyPrefill)
	local icon = require("tweezers.config").config.icons.tweezers
	local snippetDir = require("tweezers.config").config.snippetDir

	vim.ui.select(allSnipFiles, {
		prompt = vim.trim(icon .. " Select file for new snippet: "),
		format_item = function(item)
			local relPath = item.path:sub(#snippetDir + 2)
			return relPath:gsub("%.luac?$", "")
		end,
	}, function(snipFile)
		if not snipFile then return end
		edit.createNewSnipAndEdit(snipFile, bodyPrefill)
	end)
end
--------------------------------------------------------------------------------
return M
