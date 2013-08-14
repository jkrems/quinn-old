
require! path
require! deepmerge

module.exports = config-store = ->
  _state =
    env: process.env.NODE_ENV || 'development'
    app-root: process.cwd!

  _by-env = {}

  config = {}

  Object.defineProperties config,
    extend:
      value: (overrides) ->
        _state := deepmerge _state, overrides

    defaults:
      value: (defValues) ->
        _state := deepmerge defValues, _state

    configure:
      value: (env, settings) ->
        if _state.env == env
          config.extend settings
        else
          _by-env[env] = deepmerge (_by-env[env] ? {}), settings

    include-env:
      value: (env) ->
        config.extend (_by-env[env] ? {})

    current:
      get: -> _state
      enumerable: true

    get:
      value: (config-key) ->
        return config.current unless !!config-key
        traverse = (obj, part) -> obj?[part] ? null
        config-key.split '.' .reduce traverse, config.current

    app-path:
      value: (...segments) ->
        path.join config.current.app-root, ...segments

    load-app-config:
      value: (app-root) ->
        _state <<< {app-root}
        initial-file = path.join app-root, 'config'
        config.load-config-file initial-file

    load-config-file:
      value: (filename, is-optional = false) ->
        overrides =
          if is-optional
            try require filename
            catch e
              if e.code == 'MODULE_NOT_FOUND' then {}
              else throw e
          else require filename

        if 'function' == typeof overrides
          overrides config
        else
          config.extend overrides
