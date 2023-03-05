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
    d:get_raw_instance()
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
