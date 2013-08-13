
require! lodash.omit

const RESERVED_CHARACTER = /([.?*+^$[\]\\(){}-])/g
const ROUTE_SEGMENT = /((\{[a-z_$][a-z0-9_$]*\})|[*.+()])/ig

escape-regex = (symbol) ->
  String symbol .replace RESERVED_CHARACTER, '\\$1'

/**
 * Compiles the given route string into a RegExp that can be used to match
 * it. The route may contain named keys in the form of a colon followed by a
 * valid JavaScript identifier (e.g. ":name", ":_name", or ":$name" are all
 * valid keys). If it does, these keys will be added to the given keys array.
 *
 * If the route contains the special "*" symbol, it will automatically create a
 * key named "splat" and will substituted with a "(.*?)" pattern in the
 * resulting RegExp.
 */
module.exports = compile-route = (route) ->
  segments = []

  named-segment = (segment, pattern) ->
    segments.push segment
    pattern

  reverse-pattern = (params={}) ->
    used-params = []

    use-param = (name) ->
      unless params[name]?
        err = new Error "Missing route parameter: #{name}"
        err.type = 'missing_param'
        throw err
      if -1 == used-params.index-of name
        used-params.push name
      params[name]

    pathname = route.replace ROUTE_SEGMENT, (m) ->
      switch m
      | '*'           => use-param 'splat'
      | <[ . + ( ) ]> => m
      | _             => use-param m.substr(1, m.length - 2)

    query = omit params, ...used-params

    { pathname, query, used-params }

  pattern = route.replace ROUTE_SEGMENT, (m) ->
    switch m
    | '*'           => named-segment 'splat', '(.*?)'
    | <[ . + ( ) ]> => escape-regex m
    | _             => named-segment m.substr(1, m.length - 2), '([^./?#]+)'

  { segments, reverse-pattern, pattern: new RegExp "^#{pattern}$" }
