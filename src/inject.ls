
target = (dependencies, target-fn) ->
  target-with-context = (ctx) ->
    args = dependencies.map (dep) ->
      if ctx[dep]? then that
      else
        err = new Error "Unresolved dependency #{JSON.stringify String dep}"
        err.meta:
          target-fn: target-fn.to-string!
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
ARGS_PATTERN = /^function\s*[^\(]*\(\s*([^\)]*)\)/m
ARG_PATTERN = /^\s*(_?)(\S+?)\1\s*$/
target-from-fn = (target-fn) ->
  source = target-fn.to-string!.replace COMMENTS_PATTERN, ''
  [_, fn-args] = source.match ARGS_PATTERN
  dependencies = fn-args.split ',' .map (arg) -> arg.replace ARG_PATTERN, '$2'

  target dependencies, target-fn

parse-target = (raw-target) ->
  switch typeof! raw-target
  | 'Function' => target-from-fn raw-target
  | 'Array'    => target-from-array raw-target
  | _          => throw new Error "Invalid inject target: #{String raw-target}"

request-context = (req, params, varargs) ->
  ctx = { req, params, varargs }
  Object.defineProperties ctx,
    page:
      get: ->
        require! './page-model'
        page-model req
    render:
      get: ->
        default-template =
          if req.action == 'index' then req.module
          else "#{req.module}/#{req.action}"

        (tpl-name = default-template, tpl-ctx, tpl-ops) ->
          # if the first argument isn't an string, assume shift
          unless 'string' is typeof tpl-name
            [tpl-opts, tpl-ctx, tpl-name] = [tpl-ctx, tpl-name, default-template]

          tpl-ctx ?= ctx.page
          req.quinn-ctx.render tpl-name, tpl-ctx, tpl-opts
  ctx

action = (raw-target) ->
  target-with-context = parse-target raw-target

  (req, params, ...varargs) ->
    target-with-context <| request-context req, params, varargs

module.exports = inject = (raw-target, context) -->
  parse-target raw-target <| context

inject <<< { action }
