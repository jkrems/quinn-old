
require! './controller'

require! './utils/compile-route'

add-segment-accessor = (memo, segment, index) ->
  memo[segment] =
    get: -> @[index + 1]
    set: (value) !-> @[index + 1] = value
  memo

create-route = (route-or-regex, base-route) ->
  {pattern, segments} = switch typeof! route-or-regex
  | 'String' => compile-route route-or-regex
  | 'RegExp' => { pattern: route-or-regex, segments: [] }
  | _        => throw new Error "Invalid route: #{route-or-regex}"

  accessors = segments.reduce add-segment-accessor, {}
  base-route <<< { pattern, accessors }

const ANY = <[ ANY ]>

module.exports = router = ->
  routes =
    ANY: []

  handler-from-string = (ctrl-action, route-params) ->
    [module, action] = ctrl-action.split '#'
    action ?= 'index'
    { module, action, handler: controller ctrl-action, route-params }

  reverse-route = (method, ctrl-action, ...params) ->
    routes-to-try = (routes[method] ? []) ++ routes.ANY

    for route in routes-to-try
      console.log route

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

  match-route <<< push-route: (route-or-regex, handler-or-ctrl-action, route-params = {}, methods = ANY) ->
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

module.exports <<< { add-segment-accessor, create-route }
