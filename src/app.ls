
require! querystring
require! http.STATUS_CODES
require! events.EventEmitter

require! Q: q

require! './router'
require! './respond'

# Add sugar methods for common HTTP verbs. Note that GET defines
# routes for both GET *and* HEAD requests.
HTTP_VERBS =
  get: <[ GET HEAD ]>
  post: <[ POST ]>
  put: <[ PUT ]>
  patch: <[ PATCH ]>
  del: <[ DELETE ]>
  head: <[ HEAD ]>
  options: <[ OPTIONS ]>

default-route =
  params: []
  handler: ({method, pathname}) ->
    respond.text "Cannot #{method} #{pathname}", 404

default-error-handler = (req, err) ->
  respond.text err.stack, 500

map-result = (result) ->
  switch typeof! result
  | 'Function' => result
  | 'String'   => respond.text result
  | 'Number'   => respond.text STATUS_CODES[String result], result
  | 'Array'    => respond.chunks result
  | _          => respond result

send-to = (result, res) ->
  result.then map-result .fcall res

module.exports = create-app = ->
  match-route = router!
  {push-route} = match-route

  app = new EventEmitter()

  app.error-handler = default-error-handler

  app <<< handle-request: (req, res) ->
    last-resort-response = (err) ->
      res.writeHead 500, { 'Content-Type': 'text/plain' }
      res.end STATUS_CODES['500']
      app.emit 'error', err

    [pathname, search] = req.url.split '?'
    query = querystring.parse search
    req <<< { pathname, query }

    {handler, params} = (match-route req) ? default-route

    result = Q.fcall handler, req, params
    (result `send-to` res).catch( (err) ->
      result = Q.fcall app.error-handler, req, err
      result `send-to` res
    ).catch last-resort-response

  for let method, verbs of HTTP_VERBS
    app[method] = (route-or-regex, stack-or-handler) ->
      handler = stack-or-handler
      push-route route-or-regex, handler, verbs

  app <<< all: (route-or-regex, stack-or-handler) ->
    handler = stack-or-handler
    push-route route-or-regex, handler

  app
