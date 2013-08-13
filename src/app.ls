
require! http.STATUS_CODES
require! fs
require! events.EventEmitter

require! Q: q

require! './router'
require! './respond'
require! './config'
require! './patch-incoming-request'

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

default-heartbeat-handler =  (req, res) ->
  return false if req.url != '/heartbeat'
  heartbeat-file = config.app-path 'public', 'heartbeat.txt'
  fs.exists heartbeat-file, (has-heartbeat) ->
    if has-heartbeat
      res.end 'ok'
    else
      res.writeHead 404
      res.end 'No public/heartbeat.txt'
  true

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
  app.heartbeat-handler = default-heartbeat-handler

  app <<<
    handle-request: (req, res) ->
      return if app.heartbeat-handler req, res

      last-resort-response = (err) ->
        app.emit 'error', err
        try res.writeHead 500, { 'Content-Type': 'text/plain' }
        try res.end STATUS_CODES['500']

      patch-incoming-request req, res

      {handler, params} = (match-route req) ? default-route

      result = Q.fcall handler, req, params
      (result `send-to` res).catch( (err) ->
        result = Q.fcall app.error-handler, req, err
        result `send-to` res
      ).catch last-resort-response

    all: (route-or-regex, stack-or-handler) ->
      handler = stack-or-handler
      push-route route-or-regex, handler

  for let method, verbs of HTTP_VERBS
    app[method] = (route-or-regex, stack-or-handler) ->
      handler = stack-or-handler
      push-route route-or-regex, handler, verbs

  app
