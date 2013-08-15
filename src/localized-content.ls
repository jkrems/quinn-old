
require! deepmerge
require! path
require! fs.readdir-sync

module.exports = localized-content = (modules, config) ->
  messages-by-locale = {}

  add-messages = (locale, module-messages, prefix = []) ->
    obj = {}
    node = obj
    [...segments, top] = [locale].concat prefix
    segments.for-each (segment) ->
      node[segment] ?= {}
      node := node[segment]

    node[top] = module-messages
    messages-by-locale := deepmerge messages-by-locale, obj

  load-from-module = ({directory, name}) !->
    messages-path = path.join directory, 'messages'
    message-files = try readdir-sync messages-path
    message-files ?= []
    message-files.for-each (filename) ->
      ext = path.extname filename
      locale = path.basename filename, ext
      module-messages = require path.join messages-path, filename
      add-messages locale, module-messages, [name]
  modules.for-each load-from-module

  fallbacks-for-locale = (locale) ->
    ['defaults', locale]

  messages-for-locale = (locale) ->
    fallbacks = fallbacks-for-locale locale
    merge-fallback = (memo, fallback) ->
      if messages-by-locale[fallback]?
        deepmerge memo, that
      else memo

    fallbacks.reduce merge-fallback, {}

  localize = (req, res) ->
    i18n =
      country: 'US'
      lang: 'en'
      locale: 'en_US'
      scope: []
      messages: messages-for-locale 'en_US'
      lookup: (segments) ->
        segments.reduce(
          (node, key) -> node?[key]
          i18n.messages
        )
      interpolate: (node, opts, key) ->
        (String node).replace /%\{\w+\}/g, (placeholder) ->
          name = placeholder.substr 2, (placeholder.length - 3)
          opts[name] ? "[missing #{i18n.locale} value: #{JSON.stringify name}]"
      translate: (key, opts = {}) ->
        segments = key.split '.'
        if segments[0] == ''
          segments = i18n.scope.concat segments.slice 1

        node = i18n.lookup(segments) ? opts.default
        if node?
          if typeof node == 'object'
            JSON.stringify node
          else
            i18n.interpolate node, opts
        else
          "[missing #{i18n.locale}: #{JSON.stringify segments.join '.'}]"
