--
-- An implementation of mustache's logic-less templates in Lua
-- (C) 2012 Antonio Vieiro (antonio#antonioshome.net)
-- Released under the MIT license. See LICENSE for details.
--
local mostacho = function ()

  local tag_start_txt = '{{'
  local tag_end_txt = '}}'

  --[[

  Searchs 'txt' from index 'idx' seeking for a tag starting with 'tag_start_txt'
  and ending with 'tag_end_txt'.

  Returns 
    - nil if there's no tag.
    - start index, end index, tag txt and tag type on success.
      txt:sub(1,start index) and txt.sub(endindex) will return the surroundings of the tag
    - raises an error if 'tag_start_txt' is found but 'tag_end_txt' is not.

  ]]--
  local find_tag_fn = function (txt, idx)
    local is, ie = txt:find(tag_start_txt, idx, true)
    if is == nil then
      return nil
    else
      local js, je = txt:find(tag_end_txt, ie + 1, true)
      if js == nil then
        error('Unclosed tag at ' .. ie)
      else
        local tag_txt = txt:sub(ie + 1, js - 1)
        return is - 1, je + 1, tag_txt
      end
    end
  end

  --[[
  Searchs 'txt' seeking for a section-end tag of the form
    tag_start_txt '/' tag_txt tag_end_txt

  @return nil if there's no section, or start_index, end_index + txt
    on success
  ]]--
  local find_section_end_fn = function(txt, idx, tag_txt)
    local sectionEndText = tag_start_txt .. '/' .. tag_txt .. tag_end_txt
    local is, ie = txt:find(sectionEndText, idx, true)
    if is == nil then
      return nil
    else
      local sectionText = txt:sub(idx, is-1)
      return is-1, ie+1, sectionText
    end
  end

  --[[
  Escapes html txt
  ]]--
  local escape_html_fn = function(txt)
    return txt:gsub('[^a-zA-Z0-9 _]',
             function (c)
               if     c == "'" then return '&#39;'
               elseif c == '"' then return '&quot;'
               elseif c == '&' then return '&amp;'
               elseif c == '<' then return '&lt;'
               elseif c == '>' then return '&gt;'
               elseif c == ' ' then return '&nbsp;'
               else                 return c
               end
             end)
  end

  --[[
  Pushes a new environment onto the environment list.
  ]]--
  local push_environment = function (environments, new_data)
    table.insert(environments, new_data)
    return environments
  end

  --[[
  Pops an environment from the environment list
  ]]--
  local pop_environment = function (environments)
    table.remove(environments)
    return environments
  end

  --[[
  Seeks for a key in the environment list, returns nil if not found
  ]]--
  local lookup_environment = function (environments, key)
    local nenvs, env, value
    nenvs = #environments
    for nenvs = #environments, 1, -1 do
      env = environments[nenvs]
      value = env[key]
      if value ~= nil then return value end
    end
    return nil
  end

  --[[
  Counts the number of lines between indexes 1 and idx.
  ]]--
  local line_count_fn = function(txt, idx)
    local line_count = 1
    txt:sub(1,idx):gsub('\n', function (c)
        line_count = line_count + 1
        return c
      end)
    return line_count
  end

  --[[
  Some constants
  ]]--
  local TAG_HASH    = 35  -- #
  local TAG_SLASH   = 47  -- /
  local TAG_UNSCAPE = 123 -- {
  local TAG_AND     = 38  -- &
  local TAG_NOT     = 94  -- ^
  local TAG_COMMENT = 33  -- !
  local TAG_PARTIAL = 62  -- >
  local TAG_DOT     = 46  -- .
  local TAG_EQUALS  = 61  -- =
  local render_fn, render_section_fn, render_not_section_fn

  --[[ 
  Renders a section {{#section}} ... {{/section} 
    @param section_name the name of the section
    @param env_list the environment list
    @param template the text within the section
    @param idx the character index within the section text (or 1)
    @param acc an accumulator
  ]]--
  render_section_fn = function(section_name, env_list, template, idx, acc)
    local js, je, section_text = find_section_end_fn(template, idx, section_name)
    if js == nil then
      return nil, idx, 'Unclosed section "' .. section_name .. '"'
    end
    local section_value = lookup_environment(env_list, section_name)
    if not section_value then
      -- empty
    elseif type(section_value) == 'table' then
      local k,v,result, index, err
      for k,v in ipairs(section_value) do
        push_environment(env_list, v)
        result, index, err = render_fn(env_list, section_text, 1, '')
        pop_environment(env_list)
        if result == nil then 
          return nil, index, err
        end
        acc = acc ..result 
      end
    elseif type(section_value) == 'function' then
      acc = acc .. to_string(section_value(section_text))
    else
      local new_env = {}
      new_env[section_name] = section_value
      push_environment(env_list, new_env)
      acc = acc .. render_fn(env_list, section_text, 1, '')
      pop_environment(env_list)
    end
    return render_fn(env_list, template, je, acc)
  end

  --[[ 
  Renders a negative section {{^section}} ... {{/section} 
    @param section_name the name of the section
    @param env_list the environment list
    @param template the text within the section
    @param idx the character index within the section text (or 1)
    @param acc an accumulator
  ]]--
  render_not_section_fn = function(section_name, env_list, template, idx, acc)
    local js, je, section_text = find_section_end_fn(template, idx, section_name)
    if js == nil then
      return nil, idx, 'Unclosed section "' .. section_name .. '"'
    end
    local section_value = lookup_environment(env_list, section_name)
    if not section_value or  (type(section_value) == 'table' and #section_value == 0) then
      acc = acc .. render_fn(env_list, section_text, 1, '')
    end
    return render_fn(env_list, template, je, acc)
  end

  --[[ 
  Renders a mustache template
    @param env_list the environment list
    @param template the mustache text
    @param idx the character index within the section text (or 1)
    @param acc an accumulator (or '')
    @return the rendered result, or nil + err in case of error.
  ]]--
  render_fn = function (env_list, template, idx, acc)
    local is, ie, tag_txt = find_tag_fn(template, idx)

    if is == nil then
      return acc .. template:sub(idx)
    else
      acc = acc .. template:sub(idx, is)
    end

    local tag_type = tag_txt:byte(1)
    -- {{#
    if     tag_type == TAG_HASH    then
      tag_txt = tag_txt:sub(2)
      tag_txt = tag_txt:gsub("^%s*(.-)%s*$", "%1")
      return render_section_fn(tag_txt, env_list, template, ie, acc)
    -- {{=
    elseif tag_type == TAG_EQUALS  then
      if tag_txt:byte(-1) ~= TAG_EQUALS then
        return nil, ie-1, 'Missing "=" to close new tag specification'
      end
      tag_txt = tag_txt:sub(2,-2)
      tag_txt = tag_txt:gsub("^%s*(.-)%s*$", "%1")
      local new_start_txt, nmatches= tag_txt:gsub("^(%S+)%s+(%S+)$", "%1")
      if nmatches ~= 1 then
        return nil, is, 'Invalid tag specification'
      end
      local new_end_txt, nmatches = tag_txt:gsub("^(%S+)%s+(%S+)$", "%2")
      if nmatches ~= 1 then
        return nil, is, 'Invalid tag specification'
      end
      tag_start_txt = new_start_txt
      tag_end_txt = new_end_txt
      return render_fn(env_list, template, ie, acc)
    -- {{^
    elseif tag_type == TAG_NOT     then
      tag_txt = tag_txt:sub(2)
      tag_txt = tag_txt:gsub("^%s*(.-)%s*$", "%1")
      return render_not_section_fn(tag_txt, env_list, template, ie, acc)
    -- {{/
    elseif tag_type == TAG_SLASH   then
      return nil, is, 'Unexpected ' .. tag_start_txt .. tag_txt .. tag_end_txt
    -- {{!
    elseif tag_type == TAG_COMMENT then
      return render_fn(env_list, template, ie, acc)
    -- {{>
    elseif tag_type == TAG_PARTIAL then
      tag_txt = tag_txt:sub(2)
      tag_txt = tag_txt:gsub("^%s*(.-)%s*$", "%1")
      local io = io
      local file, err = io.open(tag_txt .. '.mustache', 'r')
      if file == nil then
        return nil, is, err
      else
        local file_txt = file:read("*all")
        file:close()
        acc = acc .. render_fn(env_list, file_txt, 1, '')
        return render_fn(env_list, template, ie, acc)
      end
    -- {{& and {{variable
    else
      local escape = true
      if tag_type == TAG_UNSCAPE then 
        ie = ie + 1
        tag_txt = tag_txt:sub(2)
        escape = false
      end
      if tag_type == TAG_AND then 
        tag_txt = tag_txt:sub(2) 
        escape = false
      end
      tag_txt = tag_txt:gsub("^%s*(.-)%s*$", "%1")
      local variable_value = lookup_environment(env_list, tag_txt)
      if variable_value ~= nil then
        if type(variable_value) == 'function' then
          variable_value = variable_value()
        end
        if not escape then
          acc = acc .. tostring(variable_value)
        else
          acc = acc .. escape_html_fn(tostring(variable_value))
        end
      end
      return render_fn(env_list, template, ie, acc)
    end
  end

  return {
    render = function (model, template)
      local env_list = {}
      table.insert(env_list, model)
      local result, index, err = render_fn(env_list, template, 1, '')
      if result == nil then
        local line_number = line_count_fn(template, index)
        return nil, 'ERROR:' .. line_number .. ':' .. err
      else
        return result
      end
    end
  }

end

return mostacho()

