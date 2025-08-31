---@meta

---@class Tweezers.SnacksObj
---@field idx integer
---@field score integer
---@field text string
---@field name string
---@field snippet Tweezers.SnippetObj
---@field displayName string

---@class Tweezers.snipFile
---@field path string
---@field ft string
---@field fileIsNew? boolean

---DOCS https://code.visualstudio.com/api/language-extensions/snippet-guide
---@class Tweezers.packageLua
---@field contributes { snippets: Tweezers.snippetFileMetadata[] }

---@class (exact) Tweezers.snippetFileMetadata
---@field language string|string[]
---@field path string

---@class (exact) Tweezers.SnippetObj used by this plugin
---@field fullPath string (key only set by this plugin)
---@field filetype string (key only set by this plugin)
---@field originalKey? string if not set, is a new snippet (key only set by this plugin)
---@field prefix string[] -- VS Code allows single string, but this plugin converts to array on read
---@field body string[] -- VS Code allows single string, but this plugin converts to array on read
---@field description? string
---@field fileIsNew? boolean -- the file for the snippet is newly created

---DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets
---@alias Tweezers.VSCodeSnippetDict table<string, Tweezers.VSCodeSnippet>

---@class (exact) Tweezers.VSCodeSnippet
---@field prefix string|string[]
---@field body string|string[]
---@field description? string
