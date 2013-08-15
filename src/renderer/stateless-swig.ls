
require! path
require! fs.read-file-sync

require! _: lodash
require! 'swig/lib/parser'

require! './deferred-renderer'

by-name = (memo, module) ->
  memo[module.name] = module
  memo

TemplateError = (error) ->
  render: -> "<pre>#{error.stack}</pre>"

RenderFunc = (code) ->
  # The compiled render function - this is all we need
  new Function '_context', '_parents', '_filters', '_', '_ext', [
    '_parents = _parents ? _parents.slice() : [];',
    '_context = _context || {};',
    # Prevents circular includes (which will crash node without warning)
    'var j = _parents.length,',
    '  _output = "",',
    '  _this = this;',
    # Note: this loop averages much faster than indexOf across all cases
    'while (j--) {',
    '   if (_parents[j] === this.id) {',
    '     return "Circular import of template " + this.id + " in " + _parents[_parents.length-1];',
    '   }',
    '}',
    # Add this template as a parent to all includes in its scope
    '_parents.push(this.id);',
    code,
    'return _output;'
  ].join ''

module.exports = stateless-swig = (modules, config) ->
  modules = modules.reduce by-name, {}
  encoding = 'utf8'
  CACHE = {}

  {promised-block, resolve-promised-blocks, when-helper} = deferred-renderer

  Template = (data, id) ->
    template =
      # Allows us to include templates from the compiled code
      compile-file: compile-file
      # These are the blocks inside the template
      blocks: {}
      # Distinguish from other tokens
      type: parser.TEMPLATE,
      # The template ID (path relative to template dir)
      id: id

    # The template token tree before compiled into javascript
    unless config.get 'templates.displayErrors'
      tokens = parser.parse.call template, data, render.tags, render.autoescape
    else
      try
        tokens = parser.parse.call template, data, render.tags, render.autoescape
      catch err
        return TemplateError err

    template.tokens = tokens

    # The raw template code
    code = parser.compile.call template

    renderFn =
      if code != false
        RenderFunc code
      else
        (_context, _parents, _filters, _, _ext) ->
          code = parser.compile.call template, '', _context
          fn = RenderFunc code
          fn.apply this, [ _context, _parents, _filters, _, _ext ]

    template.render = (context, parents) ->
      unless config.get 'templates.displayErrors'
        renderFn.apply this, [ context, parents, render.filters, _, render.extensions ]
      else
        try
          renderFn.apply this, [ context, parents, render.filters, _, render.extensions ]
        catch err
          TemplateError err

    return template

  get-template = (source, options) ->
    id = options.filename ? source
    if config.get('templates.cache') || options.cache
      if CACHE.hasOwnProperty id
        CACHE[id]
      else
        CACHE[id] = Template source, id
    else
      Template source, id

  compile-file = (template-name, force-allow-errors) ->
    if config.get('templates.cache') && CACHE.hasOwnProperty template-name
      return CACHE[template-name]

    [ module-name, ...segments ] = template-name.split '/'
    module = modules[module-name]
    throw new Error "Unknown module: #{module-name}" unless module?

    dirname = path.join module.directory, 'templates', ...segments
    filenames = [ "#{dirname}.html", "#{dirname}/index.html" ]

    get = ->
      excp = tpl = void

      getSingle = (filename) ->
        try
          data = read-file-sync filename, encoding
          tpl := get-template data, {filename: template-name}
        catch err
          excp := err unless err.code == 'ENOENT' && excp?

      c = 0
      while tpl == void && c < filenames.length
        getSingle filenames[c++]

      throw excp if tpl == void
      tpl

    if !config.get('templates.displayErrors') || force-allow-errors
      get!
    else
      try get!
      catch err
        TemplateError err

  render = (templateName, context = {}, options = {}) ->
    template = compile-file templateName
    unless template?
      throw new Error "Template not found: #{templateName}"

    html = template.render context
    {
      status: options.status ? 200
      headers:
        'Content-Type': 'text/html; charset=utf-8'
      body: resolve-promised-blocks html, options
    }

  render <<< do
    tags: _.clone require 'swig/lib/tags'
    filters: _.clone require 'swig/lib/filters'
    extensions: { promised-block }

  render.tags <<< do
    when: when-helper

  render
