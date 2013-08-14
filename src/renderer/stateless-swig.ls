
require! lodash.clone

by-name = (memo, module) ->
  memo[module.name] = module
  memo

TemplateError = (error) ->
  render: -> "<pre>#{error.stack}</pre>"

module.exports = stateless-swig = (modules, config) ->
  modules = modules.reduce by-name, {}
  CACHE = {}

  _tags = clone require 'swig/lib/tags'
  _filters = clone require 'swig/lib/filters'
