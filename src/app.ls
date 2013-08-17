
require! http.STATUS_CODES
require! fs
require! path
require! events.EventEmitter

require! Q: q
require! mime

require! './router'
require! './respond'
require! './config-store'
require! './patch-incoming-request'
require! './renderer/stateless-swig'
require! './discover-controllers'
require! './localized-content'
require! './services'

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
  handler: ({method, pathname, headers, app}) ->
    {config} = app

    not-found = -> respond.text "Cannot #{method} #{pathname}", 404
    if method is 'GET'
      filename = config.app-path 'public', pathname
      _response = Q.defer!
      fs.stat filename, (err, stats) ->
        if err?
          if err.code == 'ENOENT'
            return _response.resolve not-found!
          else
            return _response.reject err

        if headers['if-modified-since']?
          last-client-state = new Date that
          if last-client-state.get-time! >= stats.mtime.get-time!
            return _response.resolve {
              status: 304
              headers:
                'Content-Type': mime.lookup filename
                'Last-Modified': stats.mtime.toUTCString!
            }

        response =
          status: 200
          headers:
            'Content-Type': mime.lookup filename
            'Last-Modified': stats.mtime.toUTCString!
          body: fs.createReadStream filename

        response.body.once 'error', (err) ->
          if err.code == 'ENOENT' then _response.resolve not-found!
          else _response.reject err

        response.body.once 'open', ->
          _response.resolve response

      _response.promise
    else
      not-found!

default-error-handler = (req, err) ->
  if req.__is-html
    [summary, ...trace] = err.stack.split "\n"
    summary = summary.replace /^(\w*)Error: /, '<strong>$1Error:</strong> '
    body    = "<pre>#{summary}\n#{trace.join '\n'}</pre>"
    respond.text body, 500
  else
    respond.text err.stack, 500

default-heartbeat-handler =  ({url}, res, {app-path}) ->
  return false if url != '/heartbeat'
  heartbeat-file = app-path 'public', 'heartbeat.txt'
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
  push-route = reverse-route = match-route = null

  app = new EventEmitter()
  app <<< {match-route, reverse-route}

  app.config = config-store!
  app.error-handler = default-error-handler
  app.heartbeat-handler = default-heartbeat-handler

  app <<<
    handle-request: (req, res) ->
      return if app.heartbeat-handler req, res, app.config

      last-resort-response = (err) ->
        try res.writeHead 500, { 'Content-Type': 'text/plain' }
        try res.write STATUS_CODES['500']
        try res.end!

      patch-incoming-request req, res

      req <<< {
        app
        router: match-route
        quinn-ext: {}
      }

      {handler, module, action, params} = (match-route req) ? default-route

      result = app.execute-handler req, {handler, module, action, params}
      (result `send-to` res).catch( (err) ->
        result = Q.fcall app.error-handler, req, err
        result `send-to` res
      ).catch last-resort-response .done!

    execute-handler: (req, {handler, module, action, params}) ->
      req <<< {module, action}
      Q.fcall handler, req, params

    init-modules: (modules = []) ->
      app.controller = discover-controllers modules
      app.render = stateless-swig modules, app.config
      app.localize = localized-content modules, app.config

      match-route := router app.controller
      {push-route, reverse-route} := match-route

    load-modules: (module-base) !->
      modules = fs.readdir-sync module-base .map (name) ->
        { name, directory: path.join module-base, name }
      app.init-modules modules

    load-services: (services-config) !->
      app.service = services services-config

    all: (route-or-regex, stack-or-handler, route-params) ->
      handler = stack-or-handler
      push-route route-or-regex, handler, route-params

  for let method, verbs of HTTP_VERBS
    app[method] = (route-or-regex, stack-or-handler, route-params) ->
      handler = stack-or-handler
      push-route route-or-regex, handler, route-params, verbs

  # make sure everything works without fancy stuff
  app.init-modules!

  app
