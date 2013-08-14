
require! path

require! Q: q

discover-controllers = ->
  known-controllers = {}

  modules.for-each (module) ->
    controllerFile = path.join module.directory, 'controller'
    module.controller =
      try
        known-controllers[module.name] = require controllerFile
      catch err
        if err.code == 'MODULE_NOT_FOUND' then null
        else throw err

  controller-action = (description, options = {}) ->
    [module, action] = description.split '.'
    action ?= 'index'

    controller = known-controllers[module]
    unless controller?
      throw new Error "No known controller for module #{module}"

    unless controller[action]?
      throw new Error "Controller of module #{module} has no action #{action}"

    (req) ->
      req <<< {module, action}
      controller[action] ...

  register-controller = (name, controller) ->
    known-controllers[name] = controller

  controller-action <<< { register-controller }
