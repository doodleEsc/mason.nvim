local a = require "mason-core.async"
local path = require "mason-core.path"
local _ = require "mason-core.functional"
local registry = require "mason-registry"
local script_utils = require "mason-scripts.utils"

local MASON_DIR = path.concat { vim.loop.cwd(), "lua", "mason" }
local MASON_REGISTRY_DIR = path.concat { vim.loop.cwd(), "lua", "mason-registry" }

---@async
local function create_language_map()
    local language_map = {}
    local sorted_packages = _.sort_by(_.prop "name", registry.get_all_packages())
    _.each(function(pkg)
        _.each(function(language)
            local language_lc = language:lower()
            language_map[language_lc] = _.append(pkg.name, language_map[language_lc] or {})
        end, pkg.spec.languages)
    end, sorted_packages)

    script_utils.write_file(
        path.concat { MASON_DIR, "mappings", "language.lua" },
        "return " .. vim.inspect(language_map),
        "w"
    )
end

---@async
local function create_package_index()
    a.scheduler()
    local packages = {}
    local to_lua_path = _.compose(_.gsub("/", "."), _.gsub("^lua/", ""))
    for _, package_path in ipairs(vim.fn.glob("lua/mason-registry/*/init.lua", false, true)) do
        local package_filename = vim.fn.fnamemodify(package_path, ":h:t")
        local lua_path = to_lua_path(vim.fn.fnamemodify(package_path, ":h"))
        local pkg = require(lua_path)
        assert(package_filename == pkg.name, ("Package name is not the same as its module name %s"):format(lua_path))
        packages[pkg.name] = lua_path
    end

    script_utils.write_file(path.concat { MASON_REGISTRY_DIR, "index.lua" }, "return " .. vim.inspect(packages), "w")
end

a.run_blocking(function()
    a.wait_all {
        create_language_map,
        create_package_index,
    }
end)
