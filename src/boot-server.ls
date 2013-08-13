
require! path
require! http.create-server
require! fs.readdir-sync

try-require = (ref) ->
  try require ref
  catch e
    if e.code == 'MODULE_NOT_FOUND' then null
    else throw e

module.exports = boot-server = (app-root) ->
  quinn =
    try require "#{app-root}/node_modules/quinn"
    catch e then require './quinn'

  {controller, create-app, config, render} = quinn

  config.load-app-config app-root

  config.defaults do
    server:
      mountPoint: ''
      port: process.env.PORT || 3000

  routes = try-require "#{app-root}/config/routes"
  serverInit = try-require "#{app-root}/config/server"

  module-base = path.join app-root, 'modules'
  modules = readdir-sync module-base .map (name) ->
    { name, directory: path.join module-base, name }

  found-controllers = controller.discover-controllers modules

  found-templates = render.load-templates modules

  app = create-app!
  routes? app

  server = create-server!
  serverInit? server
  server.on 'request', app.handle-request

  port = config.get 'server.port'
  server.listen port, -> process.send? 'online'

  process.on 'message', (message) ->
    if message == 'shutdown'
      process.exit 0

  server
