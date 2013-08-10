
require! path
require! deepmerge

_state =
  env: process.env.NODE_ENV || 'development'

_by-env = {}

module.exports = config = {}

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
      path.join config.current.appRoot, ...segments

  load-app-config:
    value: (appRoot) ->
      _state <<< {appRoot}
      initial-file = path.join appRoot, 'config'
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
