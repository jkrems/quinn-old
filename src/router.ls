
require! Url: url

require! './controller'

require! './utils/compile-route'

require! lodash.is-equal
require! lodash.map
require! lodash.reduce

add-segment-accessor = (memo, segment, index) ->
  memo[segment] =
    get: -> @[index + 1]
    set: (value) !-> @[index + 1] = value
  memo

create-route = (route-or-regex, base-route) ->
  {pattern, segments, reverse-pattern} = switch typeof! route-or-regex
  | 'String' => compile-route route-or-regex
  | 'RegExp' => { pattern: route-or-regex, segments: [] }
  | _        => throw new Error "Invalid route: #{route-or-regex}"

  accessors = segments.reduce add-segment-accessor, {}
  base-route <<< { pattern, accessors, reverse-pattern }

const ANY = <[ ANY ]>

module.exports = router = ->
  routes =
    ANY: []

  handler-from-string = (ctrl-action, route-params) ->
    [module, action] = ctrl-action.split '.'
    action ?= 'index'
    { module, action, handler: controller ctrl-action, route-params }

  reverse-route = (methods = 'GET') -> (ctrl-action, ...args) ->
    [_module, _action] = ctrl-action.split '.'
    _action ?= 'index'

    if methods == 'ANY' || methods ~= [ 'ANY' ]
      methods := [ 'GET', 'POST', 'PUT', 'PATCH' ]
    else if 'string' == typeof methods
      methods := [ methods ]

    params = switch args.length
    | 0 => {}
    | 1 => args[0]
    | _ => args.reduce(
        (memo, arg, idx) ->
          memo[args[idx-1]] = arg if idx % 2 == 1
          memo
        {} )

    routes-to-try = (methods ++ 'ANY').map((method) -> routes[method] || []).reduce(
      (memo, arr) -> memo.concat arr
      []
    )

    most-used = -1
    best-match = null

    for {module, action, reverse-pattern} in routes-to-try
      continue unless reverse-pattern?
      continue unless module == _module && action == _action
      try
        { pathname, query, used-params } = reverse-pattern params
        if used-params.length > most-used
          best-match = { pathname, query }
      catch e
        throw e unless e.type is 'missing_param'

    Url.format best-match if best-match?

  match-route = ({method, pathname}) ->
    routes-to-try = (routes[method] ? []) ++ routes.ANY

    for {pattern, handler, module, action, accessors} in routes-to-try
      params = pattern.exec pathname
      continue unless params

      # Make sure we have a boring old array without `.index` etc.
      [matched, ...segmentMatches] = params
      params = [matched].concat segmentMatches.map unescape
      # Add the accessors for path segments
      Object.defineProperties params, accessors

      return { handler, module, action, params }

    return null

  push-route = (route-or-regex, handler-or-ctrl-action, route-params = {}, methods = ANY) ->
    { handler, module, action } = switch typeof! handler-or-ctrl-action
    | 'String'   => handler-from-string handler-or-ctrl-action, route-params
    | 'Function' => { handler: handler-or-ctrl-action, module: null, action: null }
    | _          => throw new Error "Invalid handler type #{typeof! handler-or-ctrl-action}: #{handler-or-ctrl-action}"
    route = create-route route-or-regex, { handler, module, action }

    methods.forEach (method) ->
      method .= to-upper-case!
      if routes[method]?
        routes[method].push route
      else
        routes[method] = [ route ]

    route

  match-route <<< { push-route, reverse-route }

module.exports <<< { add-segment-accessor, create-route }
