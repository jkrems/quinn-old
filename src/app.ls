
require! querystring
require! http.STATUS_CODES
require! events.EventEmitter

require! Q: q
require! ConcatStream: 'concat-stream'

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

with-parsed-url = (req) ->
  [pathname, search] = req.url.split '?'
  query = querystring.parse search
  req <<< { pathname, query }

parse-request-body = (headers, data) -->
  [mime, mimeMeta] = (headers['content-type'] || '').split ';'
  switch mime
  | 'application/x-www-form-urlencoded' => querystring.parse data.to-string!
  | _                                   => throw new Error "Unsupported mime type: #{mime}"

with-body-parser = (req) ->
  req.set-encoding 'utf8'
  Object.defineProperties req,
    body:
      get: ->
        @_bodyPromise ?= do ->
          deferred = Q.defer!
          bodyStream = new ConcatStream deferred~resolve
          bodyStream.once 'error', deferred~reject
          req.pipe bodyStream
          deferred.promise
    content:
      get: ->
        @_contentPromise ?= do ->
          req.body.then parse-request-body req.headers

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

    with-parsed-url req
    with-body-parser req

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
