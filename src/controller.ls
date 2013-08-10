
require! path

require! Q: q

known-controllers = {}

module.exports = controller-action = (description, options = {}) ->
  [module, action] = description.split '#'
  action ?= 'main'

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

discover-controllers = (modules) -->
  foundControllers = modules.filter((module) ->
    controllerFile = path.join module.directory, 'controller'
    module.controller =
      try require controllerFile
      catch err
        if err.code == 'MODULE_NOT_FOUND' then null
        else throw err
  ).map ({name, controller}) ->
    known-controllers[name] = controller
    name

controller-action <<< { register-controller, discover-controllers }
