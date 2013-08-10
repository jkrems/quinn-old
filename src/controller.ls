
require! path

require! Q: q

known-controllers = {}

container =
  respond: require './respond'

inject = (box) ->
  [...deps, fn] = box
  args = deps.map (dep) ->
    container[dep]
  fn.apply null, args

module.exports = controller-action = (description, options = {}) ->
  [ctrl, action] = description.split '#'
  action ?= 'main'

  unless known-controllers[ctrl]?
    throw new Error "Unknown controller: #{ctrl}"

  ->
    controller = inject known-controllers[ctrl]
    controller[action].apply this, arguments

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
