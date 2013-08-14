
require! glob
require! path
require! fs.readFileSync

require! swig
require! 'swig/lib/helpers'

{promised-blocks, resolve-promised-blocks, when-helper} = require './render/deferred-renderer'

cache-templates = false
allow-template-errors = false

template-info = {}
templates = {}

_modules = {}

template-error = (error) ->
  render: -> "<pre>#{error.stack}</pre>"

swig__compile-file = swig.compile-file
swig.compile-file = (template-name, force-allow-errors) ->
  template-name = template-name.replace /\/index$/, ''
  if cache-templates && templates.hasOwnProperty template-name
    return templates[template-name]

  get = ->
    [ module-name, ...segments ] = template-name.split '/'
    module = _modules[module-name]
    throw new Error "Unknown module: #{module-name}" unless module?

    dirname = path.join module.directory, 'templates', ...segments
    filename = dirname + '.html'

    try-filename = (filename) ->
      compiled = swig__compile-file filename, force-allow-errors

      add-template template-name, { filename, compiled }
      compiled
    try
      try-filename filename
    catch err
      throw err unless err.code == 'ENOENT'
      try-filename dirname + '/index.html'

  if allow-template-errors || force-allow-errors
    get!
  else
    try get!
    catch e then template-error e

swig.init do
  root: __dirname + '/swigs'
  cache: cache-templates
  allowErrors: true
  tags:
    when: whenHelper
    asset-url: (indent, parser) ->
      [
        helpers.set-var '__file', parser.parse-variable @args[0]
        '_output += __file;'
      ].join ''
    js-url: (indent, parser) ->
      [
        helpers.set-var '__file', parser.parse-variable @args[0]
        '_output += __file;'
      ].join ''
    path-to: (indent, parser) ->
      [
        helpers.set-var '__path', parser.parse-variable @args[0]
        '_output += __path;'
      ].join ''
    route: (indent, parser) ->
      [route-str, opts] = @args
      output = []

      if opts?
        if opts == 'true' || opts == 'false' || /^\{|^\[/.test(opts) || helpers.is-literal(opts)
          console.log opts
          output.push "var __opts = #{opts};"
        else
          output.push helpers.set-var '__opts', parser.parse-variable opts
      else
        output.push 'var __opts = {};'

      log = (str) ->
        console.log str
        str

      output.concat [
        helpers.set-var '__r', parser.parse-variable route-str
        '_output += _context.router.reverseRoute(["GET"], __r, __opts);'
      ] .join ''

  extensions: { promised-block }
  filters:
    path-to: (input) -> input
    asset-url: (input) -> input
    _t: (input, opts) -> input + JSON.stringify opts

render = (templateName, context = {}, options = {}) ->
  template = swig.compile-file templateName
  unless template?
    throw new Error "Template not found: #{templateName}"

  rendered = template.render context

  {
    status: options.status ? 200
    headers:
      'Content-Type': 'text/html; charset=utf-8'
    body: resolve-promised-blocks rendered, options
  }

add-template = (name, template) ->
  templates[name] = template.compiled
  templateInfo[name] = template
  template

load-templates = (modules) ->
  _modules := modules.reduce(
    (acc, module) ->
      acc[module.name] = module
      acc
    {}
  )

render <<< {add-template, load-templates}

module.exports = render
