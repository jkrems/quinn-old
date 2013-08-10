
const RESERVED_CHARACTER = /([.?*+^$[\]\\(){}-])/g
const ROUTE_SEGMENT = /((:[a-z_$][a-z0-9_$]*)|[*.+()])/ig

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

  pattern = route.replace ROUTE_SEGMENT, (m) ->
    switch m
    | '*'           => named-segment 'splat', '(.*?)'
    | <[ . + ( ) ]> => escape-regex m
    | _             => named-segment m.substring(1), '([^./?#]+)'

  { segments, pattern: new RegExp "^#{pattern}$" }
