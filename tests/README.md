Most of these unit tests are from mustache.js

I've modified them where I tend to differ in the interpretation of mustache from mustache.js,
and where Lua is different from JavaScript.

For instance, {} in Lua can be interpreted both as an array and as an object,
and this has different meanings in the evaluation of templates in mustache.

I also have different intepretations of whitespace (for me tags just
get removed, but not line endings around them). It seems mustache.js, and probably the Ruby
implementation that I don't know, has a different interpretation of whitespace.
I've modified the .txt files to match my criteria.

