
require! path
require! http.create-server
require! fs.readdir-sync

try-require = (ref) ->
  try require ref
  catch e
    if e.code == 'MODULE_NOT_FOUND' then null
    else throw e

module.exports = boot-server = (app-root) ->
  {create-app, render} =
    try require "#{app-root}/node_modules/quinn"
    catch e then require './quinn'

  routes = try-require "#{app-root}/config/routes"
  server-init = try-require "#{app-root}/config/server"

  {config, load-modules} = app = create-app!

  config.load-app-config app-root
  config.defaults do
    server:
      mountPoint: ''
      port: process.env.PORT || 3000

  load-modules config.app-path 'modules'

  routes? app

  server = create-server!
  server-init? server
  server.on 'request', app.handle-request

  port = config.get 'server.port'
  server.listen port, -> process.send? 'online'

  process.on 'message', (message) ->
    if message == 'shutdown'
      process.exit 0

  server
