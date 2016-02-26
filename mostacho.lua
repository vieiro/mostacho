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
    if not is then
      return nil
    else
      local js, je = txt:find(tag_end_txt, ie + 1, true)
      if not js then 
        error('Unclosed tag at ' .. ie)
      else
        local tag_txt = txt:sub(ie + 1, js - 1)
        return is - 1, je + 1, tag_txt
      end
    end
  end

  --[[
  Searchs for {{#'txt'}} or for {{^'txt'}} returns the one closest for index
  ]]--
  local find_section_start_fn = function(txt, idx, tag_txt)
    local sectionStartText = table.concat({tag_start_txt, '#', tag_txt, tag_end_txt})
    local negSectionStartText = table.concat({tag_start_txt, '^', tag_txt, tag_end_txt})
    local is, ie = txt:find(sectionStartText, idx, true)
    local is2, ie2 = txt:find(negSectionStartText, idx, true)
    if not is and not is2 then
      return nil
    else
      if not is then return is2-1, ie2+1, txt:sub(idx, is2-1) end
      if not is2 then return is-1, ie+1, txt:sub(idx, is-1) end
      if is < is2    then return is-1, ie+1, txt:sub(idx, is-1) end
      if is2 < is    then return is2-1, ie2+1, txt:sub(idx, is2-1) end
      error("All work and no sleep makes Antonio a dull boy")
    end
  end

  --[[
  Searchs for {{/'txt'}}, takes care of nesting

  @return nil if there's no section, or start_index, end_index + txt
    on success
  ]]--
  local find_section_end_fn 
  find_section_end_fn = function(txt, idx, tag_txt)
    local sectionEndText = table.concat({tag_start_txt, '/', tag_txt, tag_end_txt})
    local is, ie = txt:find(sectionEndText, idx, true)
    if not is then
      return nil
    else
      local sectionText = txt:sub(idx, is-1)
      -- Does the sectionText contain a start tag
      local js, je, dummy = find_section_start_fn(txt, idx, tag_txt)
      if not js or js > is then
        -- No, there's no start tag there...
        return is-1, ie+1, sectionText
      else
        -- Yes, there's a start tag. Seek its closest end tag...
        local ks, ke, dummy = find_section_end_fn(txt, je, tag_txt)
        if not ks then
           return nil, js, 'Unclosed end tag'
        end
        sectionText = txt:sub(idx, ke-1)
        local ks, ke, dummy = find_section_end_fn(txt, ke, tag_txt)
        if not ks then
           return nil, js, 'Unclosed end tag'
        end
        -- And return our section end from that index
        return is, ke, sectionText
      end
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
  Dumps an environment
  ]]--
  local dump_environments = function(environments)
    local i,t, k,v
    for i,t in ipairs(environments) do
      local s = string.rep('  ',i)
      for k,v in pairs(t) do
        print(table.concat({s, i, ' ', k, '=', tostring(v)}))
      end
    end
  end

  --[[
  Pops an environment from the environment list
  ]]--
  local pop_environment = function (environments)
    table.remove(environments)
    return environments
  end

  local seek_dotted_key_in_table = function (t, key)
    local prefix,suffix = key:match('^([^%.]*)%.*(.*)')
    local value = t[prefix]
    if suffix == '' then 
      return value
    else
      if type(value) == 'table' then
        return seek_dotted_key_in_table(value, suffix)
      else
        return nil
      end
    end
  end

  --[[
  Seeks for a key in the environment list, returns nil if not found
  ]]--
  local lookup_environment = function (environments, key)
    local nenvs, env, value
    local prefix,suffix = key:match('^([^%.]*)%.*(.*)')
    nenvs = #environments
    for nenvs = #environments, 1, -1 do
      env = environments[nenvs]
      value = env[prefix]
      if value ~= nil then 
        if suffix == '' then 
          return value 
        else
          if type(value) == 'table' then
            return seek_dotted_key_in_table(value, suffix)
          end
        end
      end
    end
    return nil
  end

  --[[
  Detects if a Lua table is an array or an object
  ]]--
  local is_array_fn = function (t)
    local k,v,i
    local math = math
    local max_idx, count = 0, 0
    for k,v in pairs(t) do
      local t = type(k)
      if t ~= 'number' then return false end
      if k <= 0 or math.floor(k) ~= k then return false end
      max_idx = math.max(max_idx, k)
      count = count + 1
    end
    return count == max_idx
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

    if not js then
      return nil, idx, table.concat({'Unclosed #section "', section_name, '"'})
    end
    local section_value = lookup_environment(env_list, section_name)
    if not section_value then
      -- empty
    elseif type(section_value) == 'table' then
      local k,v,result, index, err
      local array = is_array_fn(section_value)


      result = ''
      if not array then
        -- Push the table itself as the environment (non-false values)
        push_environment(env_list, section_value)
        result, index, err = render_fn(env_list, section_text, 1, {})
        pop_environment(env_list)
        if not result then return nil, index, err end
        table.insert(acc, result)
      else
        -- Iterate over the array too
        for k,v in ipairs(section_value) do
          push_environment(env_list, v)
          result, index, err = render_fn(env_list, section_text, 1, {})
          pop_environment(env_list)
          if not result then return nil, index, err end
          table.insert(acc, result)
        end
      end
    elseif type(section_value) == 'function' then
      table.insert(acc, to_string(section_value(section_text)))
    else
      table.insert(acc, render_fn(env_list, section_text, 1, {}))
      --[[
      local new_env = {}
      new_env[section_name] = section_value
      push_environment(env_list, new_env)
      acc = acc .. render_fn(env_list, section_text, 1, '')
      pop_environment(env_list)
      ]]--
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
    if not js then
      return nil, idx, table.concat({'Unclosed ^section "', section_name, '"'})
    end
    local section_value = lookup_environment(env_list, section_name)
    if not section_value or  (type(section_value) == 'table' and #section_value == 0) then
      local result, idx, err = render_fn(env_list, section_text, 1, {})
      if not result then
        return nil, idx, err
      end
      table.insert(acc, result)
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
    assert(template, 'La plantilla no puede ser nil')
    local is, ie, tag_txt = find_tag_fn(template, idx)

    if not is then
      table.insert(acc, template:sub(idx))
      return table.concat(acc)
    else
      table.insert(acc, template:sub(idx, is))
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
      return nil, is, table.concat({'Unexpected ', tag_start_txt, tag_txt, tag_end_txt})
    -- {{!
    elseif tag_type == TAG_COMMENT then
      return render_fn(env_list, template, ie, acc)
    -- {{>
    elseif tag_type == TAG_PARTIAL then
      tag_txt = tag_txt:sub(2)
      tag_txt = tag_txt:gsub("^%s*(.-)%s*$", "%1")
      local io = io
      local file, err = io.open(tag_txt .. '.mustache', 'r')
      if not file then
        return nil, is, err
      else
        local file_txt, err = file:read("*all")
        file:close()
        if not file_txt then return nil, err end
        table.insert(acc, render_fn(env_list, file_txt, 1, {}))
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
          table.insert(acc, tostring(variable_value))
        else
          local txt = escape_html_fn(tostring(variable_value))
          table.insert(acc, txt)
        end
      end
      return render_fn(env_list, template, ie, acc)
    end
  end

  return {
    render = function (model, template)
      local env_list = {}
      table.insert(env_list, model)
      local result, index, err = render_fn(env_list, template, 1, {})
      if not result then
        local line_number = line_count_fn(template, index)
        return nil, table.concat({'ERROR:', line_number, ':', index, ':', err})
      else
        assert(#env_list == 1, 'Environments not cleaned up correctly')
        return result
      end
    end
  }

end

return mostacho()

