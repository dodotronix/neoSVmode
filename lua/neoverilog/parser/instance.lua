local LanguageTree = require('vim.treesitter.languagetree')

I = {}

function I:new(instance_tree, str_content, wrapped_content)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               name = "",
               autoparam = false,
               autoinst = false,
               assignments = {},
               prams_all = {},
               vars_all = {}
              }
    setmetatable(d, self)
    self.__index = self
    d:get_ports()
    -- d:get_raw_instance()
    return d
end

function I.from_str_content(str_content)
    -- this is very important, if the parsed instance is placed inside a fake 
    -- module, we can use the treesitter to parse the vars and params, because
    -- the sexp names are then consistent 
    local w_content = string.format("module w;\n%s\nendmodule", str_content)
    local trees = LanguageTree.new(w_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
            return I:new(trees[1],  w_content)
    end
    return nil
end

-- deprecated function - can't match interfaces
--[[ function I:parse_instance()
    self.name = string.match(self.str_content, "([%w_]+)")
    -- get brackets with prameters and ports
    for i in  string.gmatch(self.str_content, "([^%.]%b())") do
        local map = {}
        for n in string.gmatch(i, "([%./][%w_%(%)%*/]+)[,%)]") do
            print(n)
            table.insert(map, 1, {})
            map[1] = {
                name = string.match(n, "%.?([/%*%w_]+)"),
                value = string.match(n, "%((.-)%)")}
            -- check if the name is a macro
            if string.match(map[1].name, "/%*%u+%*/") then
                self.auto = true
            end
        end
        table.insert(self.assignments, 1, {})
        self.assignments[1] = map
    end
end ]]

function I.wrap_instance(content)
end

function I:get_ports()
    print(self.str_content)
end

function I:get_parameters()
end

function I:get_list_of_variables()
end

function I:get_portmap_from_definition()
    -- find the module definition
    -- parse the portmap
    -- create table
end

-- TODO find all definitions for the module instances 
-- TODO find the remaining port names to be able to unfold them
-- TODO get the portmaps from each of the file (dont forget, that 
-- there could be more module definitions per file
-- TODO get the portmaps and if the user forgotten .* add it

function I:get_raw_instance()
    print(self.str_content)
end

return I
