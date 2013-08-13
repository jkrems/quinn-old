
require! glob
require! fs.readFileSync

require! swig

require! stream.Duplex
require! 'swig/lib/helpers'
require! uuid: 'node-uuid'

promised-blocks = {}

promised-block = (promise, fn, name) ->
  kindaUniq = "<!--Q:$#{uuid.v4!}-->"
  promised-blocks[kindaUniq] = {promise, fn, name}
  kindaUniq

class ResolveTemplateStream extends Duplex
  (@_buffer, opts = {}) ->
    @_next-block = null
    @_timeout = opts.timeout ? 2000
    super opts

  _get-next-block: ->
    if @_next-block?
      block = @_next-block
      @_next-block = null
      { skipped: '', block }
    else
      marker-idx = @_buffer.index-of '<!--Q:$'
      if marker-idx == -1
        skipped = @_buffer
        @_buffer = ''
        { skipped, block: null }
      else
        skipped = @_buffer.substr 0, marker-idx
        marker-end = (@_buffer.index-of '-->', marker-idx) + 3
        if marker-idx == -1
          throw new Error 'Unclosed marker in deferred template'
        marker = @_buffer.substring marker-idx, marker-end
        @_buffer = @_buffer.substr marker-end

        block = promised-blocks[marker]
        throw new Error "Invalid block id: #{marker}" unless block?

        { skipped, block }

  _read: ->
    @_timer ?= set-timeout(
      ~>
        if @_next-block? || @_buffer != ''
          waited-for = @_next-block?.name ? '<unknown>'
          err = new Error "Rendering timed out while waiting for #{waited-for}"
          err.renderBuffer = @_buffer
          @emit 'error', err
          @push null
        @_next-block = null
        @_buffer = ''
      @_timeout
    )

    if @_buffer == ''
      clear-timeout @_timer
      @push null

    { skipped, block } = @_get-next-block!
    @push skipped if skipped != ''

    if block?
      { promise, fn } = block
      { state, value, reason } = promise.inspect!
      switch state
      | 'pending'
        @_next-block = block
        promise.then ~> @emit 'readable'
        @push ''
      | 'fulfilled'      => @push fn value
      | 'rejected'       => @emit 'error', reason
      | _                => @emit 'error', new Error "Promise in invalid state: #{promise}.state = #{state}"

whenHelper = (indent, parser) ->
  {name} = parser.parse-variable @args[0]

  varname =
    if @args.length == 3 && @args[1] == 'as'
      helpers.escapeVarName @args[2], '_context'
    else
      helpers.escapeVarName @args[0], '_context'

  render = new Function 'v', [
    'var _output = "";'
    "#{varname} = v;"
    parser.compile.call @, "#{indent}"
    'return _output;'
  ].join('')

  [
    helpers.setVar '__p', parser.parse-variable @args[0]
    "var __n = #{JSON.stringify name};"
    'var __i = ("function" === typeof __p.inspect) ? __p.inspect() : {state:"fulfilled",value:__p};'
    "var __render = #{render.to-string!};"
    'switch(__i.state) {'
    'case "rejected": throw __i.reason;'
    "case 'pending': _output += _ext.promisedBlock(__p, __render, __n); break;"
    'default: _output += __render(__i.value); break;'
    '}'
  ].join ''

whenHelper.ends = true

swig.init do
  root: __dirname + '/swigs'
  allowErrors: true
  tags:
    when: whenHelper
    _t: (indent, parser) ->
      output = []

      if @args.length > 1
        opts = @args[1]
        if opts == 'true' || opts == 'false' || /^\{|^\[/.test(opts) || helpers.is-literal(opts)
          output.push "var __opts = #{opts};"
        else
          output.push helpers.set-var '__opts', parser.parse-variable opts

      output.concat [
        helpers.set-var '__key', parser.parse-variable @args[0]
        '_output += _context.I18n.translate(__key, __opts);'
      ] .join ''
    asset-url: (indent, parser) ->
      [
        helpers.set-var '__file', parser.parse-variable @args[0]
        '_output += __file;'
      ].join ''
    path-to: (indent, parser) ->
      [
        helpers.set-var '__path', parser.parse-variable @args[0]
        '_output += __path;'
      ].join ''

  extensions: { promised-block }
  filters:
    path-to: (input) -> input
    asset-url: (input) -> input
    _t: (input, opts) -> input + JSON.stringify opts

templateInfo = {}
templates = {}

render = (templateName, context = {}, options = {}) ->
  template = templates[templateName]
  unless template?
    throw new Error "Template not found: #{templateName}"

  rendered = template context

  {
    status: options.status ? 200
    headers:
      'Content-Type': 'text/html; charset=utf-8'
    body: new ResolveTemplateStream rendered, options
  }

add-template = (name, template) ->
  templates[name] = template.compiled
  templateInfo[name] = template
  template

load-templates = (modules) ->
  modules.forEach ({name, directory}) ->
    templatesPath = "#{directory}/templates/"

    files = glob.sync "#{templatesPath}**/*.html"
    files.forEach (filename) ->
      rel = filename.replace templatesPath, '' .replace '.html', ''
      pathSegments = [name].concat rel.split '/'
      if pathSegments[pathSegments.length - 1] == 'index'
        pathSegments.pop!

      templateName = pathSegments.join '_'

      source = readFileSync filename .toString!
      compiled = swig.compile source, {filename: templateName}

      add-template templateName, { filename, source, compiled }

render <<< {add-template, load-templates}

module.exports = render
