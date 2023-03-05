local LanguageTree = require('vim.treesitter.languagetree')

I = {}

function I:new(instance_tree, str_content)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               prams = {},
               vars = {}
              }
    setmetatable(d, self)
    self.__index = self
    d:parse_instance()
    -- d:get_raw_instance()
    return d
end

function I.from_str_content(str_content)
    local trees = LanguageTree.new(str_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
            return I:new(trees[1], str_content)
    end
    return nil
end

function I:parse_instance()
    -- print(self.str_content)
    -- local name = string.gsub(self.str_content, "^([%w_]+).*", "%1")
        -- local portmap = string.gsub(self.str_content, "")
    --[[ for i in  string.match(self.str_content, ".[%w_]+%([%w_]+%)") do
        print(i)
    end ]]
    -- local parameters = string.gsub(self.str_content, "")
    -- read all  
    --[[ for i, n in instance_query:iter_captures(self.instance_tree:root(), self.str_content) do
        local group = instance_query.captures[i]
        print(group)
    end ]]
end

function I:get_list_of_variables()

end

function I:get_portmap()
    -- find the module definition
    -- parse the portmap
    -- create table
end

-- TODO get the portmaps with .* and find the remaining port names 
-- to be able to unfold them
-- TODO find all definitions for the module instances 
-- TODO get the portmaps from each of the file (dont forget, that 
-- there could be more module definitions per file
-- TODO get the portmaps and if the user forgotter .* add it

function I:get_raw_instance()
    print(self.str_content)
end

return I
