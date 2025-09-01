local M = {}
--------------------------------------------------------------------------------

---@param allSnippets Tweezers.SnippetObj[]
function M.selectSnippet(allSnippets)
	local icon = require("tweezers.config").config.icons.tweezers
	local prompt = vim.trim(icon .. " Select snippet: ")
	local picker = require("tweezers.config").config.snippetSelection.picker
	local hasTelescope, _ = pcall(require, "telescope")
	local hasSnacks, _ = pcall(require, "snacks")

	if picker == "telescope" or (picker == "auto" and hasTelescope) then
		require("tweezers.2-picker.telescope").selectSnippet(allSnippets, prompt)
	elseif picker == "snacks" or (picker == "auto" and hasSnacks) then
		require("tweezers.2-picker.snacks").selectSnippet(allSnippets, prompt)
	else
		require("tweezers.2-picker.vim-ui-select").selectSnippet(allSnippets, prompt)
	end
end

--------------------------------------------------------------------------------
return M
