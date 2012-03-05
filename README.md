# mustache implementation in Lua

This is a simple implementation of [Mustache](http://mustache.github.com/) in [Lua](http://www.lua.org/).

See [http://mustache.github.com/mustache.5.html] for details on mustache.

## How to use

Mostacho does not use Lua modules but [closures](http://lua-users.org/wiki/LuaModuleFunctionCritiqued). You can use Mostacho like so:

    local mostacho = require 'mostacho'

    local template = [[ This is {{name}}. ]]
    local model = { name = 'Mostacho' }

    local rendered, err = mostacho.render(model, template)

    if rendered == nil then
      error(err)
    else
      print(rendered)
    end

## Goals

* to be fast.
* and to be fully compatible with mustache.
* no external dependencies.
* maybe I want to compile templates in the future (to avoid parsing them again and again).

## Non goals

The [mustache processor](http://mustache.github.com/mustache.1.html) won't be
implemented in the near term.

## Features

Errors in templates (unclosed sections, missing end tags) are reported with line numbers.

## Status

I'm working on it as a hobby project, no hurries.

* '{{', '{{&', '{{#', '{{/' , '{{!' are implemented.
* '{{{' and '{{=' are not implemented yet.
* Missing (public) unit tests. Deciding on a non-dependent solution yet.

## License

Mostacho is released under the [MIT License](http://www.opensource.org/licenses/mit-license.php)

Mostacho is copyrighted (C) 2012 by Antonio Vieiro (antonio#antonioshome.net)
