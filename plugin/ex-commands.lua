vim.api.nvim_create_user_command(
	"TweezersAddNewSnippet",
	function(args) require("tweezers.1-prepare-selection").addNewSnippet(args) end,
	{ desc = "Add new snippet.", range = true }
)

vim.api.nvim_create_user_command(
	"TweezersEditSnippet",
	function() require("tweezers.1-prepare-selection").editSnippet() end,
	{ desc = "Edit existing snippet." }
)
