
require! Q: q

require! './page-model'
require! '../harmony/wrap-generator'

target = (dependencies, target-fn) ->
  target-with-context = (ctx) ->
    args = dependencies.map (dep) ->
      if ctx[dep]? then that
      else
        err = new Error "Unresolved dependency #{JSON.stringify String dep}"
        err.meta:
          target-fn: target-fn.name
          dependencies: dependencies
          dependency: dep
        throw err

    switch args.length
    |  0 => target-fn!
    |  1 => target-fn args[0]
    |  2 => target-fn args[0], args[1]
    |  3 => target-fn args[0], args[1], args[2]
    |  4 => target-fn args[0], args[1], args[2], args[3]
    |  5 => target-fn args[0], args[1], args[2], args[3], args[4]
    |  6 => target-fn args[0], args[1], args[2], args[3], args[4], args[5]
    |  7 => target-fn args[0], args[1], args[2], args[3], args[4], args[5], args[6]
    |  8 => target-fn args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]
    |  9 => target-fn args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
    | 10 => target-fn args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]
    | _  => target-fn.apply void, args

# ported from angular.js
COMMENTS_PATTERN = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
ARGS_PATTERN = /^function\s*(\*)?\s*[^\(]*\(\s*([^\)]*)\)/m
ARG_PATTERN = /^\s*(_?)(\S+?)\1\s*$/
target-from-fn = (target-fn) ->
  source = target-fn.to-string!.replace COMMENTS_PATTERN, ''
  [_, gen-marker, fn-args] = source.match ARGS_PATTERN
  dependencies = fn-args.split ',' .map (arg) -> arg.replace ARG_PATTERN, '$2'
  dependencies = dependencies.filter (dep) -> dep

  # support harmony generators
  target-fn = wrap-generator target-fn

  target dependencies, target-fn

parse-target = (raw-target) ->
  switch typeof! raw-target
  | 'Function' => target-from-fn raw-target
  | 'Array'    => target-from-array raw-target
  | _          => throw new Error "Invalid inject target: #{String raw-target}"

request-context = (req, params, varargs) ->
  {app} = req
  default-template =
    if req.action == 'index' then req.module
    else "#{req.module}/#{req.action}"

  ctx = { req, params, varargs } <<< app{controller,config}
  ctx <<< req.quinn-ext if req.quinn-ext?

  Object.defineProperties ctx,
    present:
      value: (presenter, data) ->
        Q.when data, presenter
    service:
      value: (svc-name) ->
        app.service svc-name, ctx.req, ctx.i18n
    page:
      get: ->
        @_page ?= page-model req, @i18n
    i18n:
      get: ->
        unless @_i18n?
          @_i18n = app.localize? req
          @_i18n <<< {scope: [req.module]} if req.module?
        @_i18n
    session:
      value: req.session
    cookies:
      value: req.cookies
    config:
      value: app.config
    render:
      value: (tpl-name = default-template, tpl-ctx, tpl-opts) ->
        req.__is-html = true

        # if the first argument isn't an string, assume shift
        unless 'string' == typeof tpl-name
          [tpl-opts, tpl-ctx, tpl-name] = [tpl-ctx, tpl-name, default-template]

        tpl-ctx ?= ctx.page
        app.render tpl-name, tpl-ctx, tpl-opts
    forward:
      value: (fwd-module-action, override-params = {}) ->
        fwd-params = {}
        fwd-params <<< params
        fwd-params <<< override-params

        [fwd-module, fwd-action] = fwd-module-action.split '.'
        fwd-module ||= req.module
        fwd-action ||= 'index'

        app.execute-handler req,
          module: fwd-module
          action: fwd-action
          handler: app.controller "#{fwd-module}.#{fwd-action}"
          params: fwd-params

action = (raw-target) ->
  target-with-context = parse-target raw-target

  (req, params, ...varargs) ->
    target-with-context <| request-context req, params, varargs

module.exports = inject = (raw-target, context) -->
  parse-target raw-target <| context

inject <<< { action }
