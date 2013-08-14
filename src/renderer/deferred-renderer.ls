
require! stream.Duplex

require! uuid: 'node-uuid'
require! 'swig/lib/helpers'

when-helper = (indent, parser) ->
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
    helpers.set-var '__p', parser.parse-variable @args[0]
    "var __n = #{JSON.stringify name};"
    'var __i = ("function" === typeof __p.inspect) ? __p.inspect() : {state:"fulfilled",value:__p};'
    "var __render = #{render.to-string!};"
    'switch(__i.state) {'
    'case "rejected": throw __i.reason;'
    "case 'pending': _output += _ext.promisedBlock(__p, __render, __n); break;"
    'default: _output += __render(__i.value); break;'
    '}'
  ].join ''

when-helper <<< { ends: true }

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

resolve-promised-blocks = (rendered, options) ->
  new ResolveTemplateStream rendered, options

module.exports <<< {promised-blocks, resolve-promised-blocks, when-helper, ResolveTemplateStream}
