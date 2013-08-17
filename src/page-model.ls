
object-from-array = (arr) ->
  obj = {}
  arr.for-each (el, idx) ->
    if idx % 2 == 1
      obj[arr[idx-1]] = el
  obj

i18n-helpers = (i18n) ->
  _t: (key, ...opts) ->
    if opts.length > 1
      opts = object-from-array opts
    else if typeof opts[0] == 'object'
      opts = opts[0] ? {} # handle null
    else
      opts = {}

    i18n.translate key, opts

url-helpers = (req) ->
  route: req.router.reverse-route!
  asset-url: (filename) -> filename

module.exports = page-model = (req, i18n) ->
  page = {}
  page <<< url-helpers req
  page <<< i18n-helpers i18n

page-model <<< { i18n-helpers, url-helpers }
