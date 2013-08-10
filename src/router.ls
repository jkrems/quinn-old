
require! './utils/compile-route'

add-segment-accessor = (memo, segment, index) ->
  memo[segment] =
    get: -> @[index + 1]
    set: (value) !-> @[index + 1] = value
  memo

create-route = (route-or-regex, handler) ->
  {pattern, segments} = switch typeof! route-or-regex
  | 'String' => compile-route route-or-regex
  | 'RegExp' => { pattern: route-or-regex, segments: [] }
  | _        => throw new Error "Invalid route: #{route-or-regex}"

  {
    pattern, handler
    accessors: segments.reduce add-segment-accessor, {}
  }

const ANY = <[ ANY ]>

module.exports = router = ->
  routes =
    ANY: []

  match-route = ({method, pathname}) ->
    routes-to-try = (routes[method] ? []) ++ routes.ANY

    for {pattern, handler, accessors} in routes-to-try
      params = pattern.exec pathname
      continue unless params

      # Make sure we have a boring old array without `.index` etc.
      params = [] ++ params
      # Add the accessors for path segments
      Object.defineProperties params, accessors

      return { handler, params }

    return null

  match-route <<< push-route: (route-or-regex, handler, methods = ANY) ->
    route = create-route route-or-regex, handler

    methods.forEach (method) ->
      method .= to-upper-case!
      if routes[method]?
        routes[method].push route
      else
        routes[method] = [ route ]

    route

module.exports <<< { add-segment-accessor, create-route }
