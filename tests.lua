
local mostacho = require 'mostacho'
local verbose = true

--
-- Reads a file, returns its content
--
local file_read_fn = function (filename)

  local file, err = io.open(filename, 'r')
  if file == nil then return nil,err end
  local txt, err = file:read('*all')
  file:close()
  return txt, err

end

--
-- Compares a string with the contents of a file
--
local check_result_fn = function(rendered_txt, expected_contents_filename)

  local expected_txt, err = file_read_fn(expected_contents_filename)

  if expected_txt == nil then error(err) end

  local match = expected_txt == rendered_txt

  if verbose and not match then
    print('The following result does not match the contents of ' .. expected_contents_filename)
    print('Expected:')
    print('[[' .. expected_txt .. ']]')
    print('Rendered:')
    print('[[' .. rendered_txt .. ']]')
  end

  return match

end

--
-- Given a 'name' this function
-- a) Reads the 'view' (I call it model) from the file name.lua
-- b) Reads a template from name.mustache
-- c) Uses mostacho to render the template with the given model
-- d) Compares the rendered result with the contents of 'name.txt'
--

local test = function (name)

  -- Load the model from name .. '.lua'
  local model = loadfile( name .. '.lua')
  if model == nil then error(name .. '.lua does not exist!') end
  model = model()

  -- Load the template
  local template = file_read_fn(name .. '.mustache')

  -- Render the result
  local rendered, err = mostacho.render(model, template)

  if rendered == nil then 
    print('ERROR - ' .. name .. ' Error rendering result mustacho said that "' .. err .. '"')
  else
    -- Compare the result with name .. '.txt'
    local ok = check_result_fn(rendered, name .. '.txt') 

    if ok then 
      print('OK    - ' .. name)
    else
      print('ERROR - ' .. name)
    end
  end

end

test('tests/comments')
test('tests/ampersand_escape')
test('tests/apostrophe')
test('tests/backslashes')
test('tests/bug_11_eating_whitespace')
test('tests/delimiters')
test('tests/double_render')
test('tests/empty_sections')
test('tests/empty_string')
test('tests/empty_template')
test('tests/error_not_found')
test('tests/escaped')
test('tests/included_tag')
test('tests/inverted_section')
test('tests/keys_with_questionmarks')
test('tests/multiline_comment')
test('tests/nested_iterating')
test('tests/nesting')
test('tests/null_string')
test('tests/partial_array_of_partials')
test('tests/whitespace')
