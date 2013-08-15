
require! Q: q
require! request
require! deepmerge

chain-forwards = <[ jar oauth httpSignature aws auth getHeader json multipart form qs setHeader setHeaders ]>

module.exports = services = (services-config = {}) ->

  service = (svc-name, req, i18n) ->
    fetch = (uri, options = {}) ->
      options.only20x ?= true

      deferred = Q.defer!

      conf = services-config[svc-name]
      if conf?
        if conf.map-args?
          { uri, options } = conf.map-args uri, options, req, i18n
        if conf.defaults?
          options = deepmerge conf.defaults, options

        stream = request uri, options, (error, response, body) ->
          if error?
            deferred.reject error
          else
            if response.statusCode < 400 || !options.only20x
              deferred.fulfill { response, body }
            else
              err = new Error "Non-20x status code from service (#{response.statusCode})"
              err <<< { response, body }
              deferred.reject err
      else
        deferred.reject new Error "Unknown service: #{svc-name}"

      promise = chain-forwards.reduce(
        (p, fwd) ->
          p[fwd] = ->
            stream?[fwd] ...
            p
          p
        deferred.promise
      )

      Object.define-properties promise,
        stream:
          value: stream
        as-json:
          get: -> @get 'body' .then (body) ->
            if 'string' == typeof body then JSON.parse body
            else body
        has-header:
          value: -> stream?.set-headers ...
        get-header:
          value: -> stream?.get-header ...

    fetch <<<
      get: fetch
      patch: (uri, options = {}) ->
        options.method = 'PATCH'
        fetch uri, options
      post: (uri, options = {}) ->
        options.method = 'POST'
        fetch uri, options
      put: (uri, options = {}) ->
        options.method = 'PUT'
        fetch uri, options
      del: (uri, options = {}) ->
        options.method = 'DELETE'
        fetch uri, options
      head: (uri, options = {}) ->
        options.method = 'HEAD'
        fetch uri, options
      jar: request.jar
      cookie: request.cookie
