local mostacho = require 'mostacho'

local template = [[ This is {{name}}. ]]
local model = { name = 'Mostacho' }

local rendered, err = mostacho.render(model, template)

if rendered == nil then
  error(err)
else
  print(rendered)
end

