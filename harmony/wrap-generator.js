'use strict';

var Q           = require('q'),
    isGenerator = require('./util').isGenerator;

// ported from Q
module.exports = function wrapGenerator(makeGenerator) {
  return function() {
    var callback, errback;

    function continuer(verb, arg) {
      try {
        var result = generator[verb](arg);
        return result.done ?
          result.value : Q.when(result.value, callback, errback);
      } catch (exception) {
        return Q.reject(exception);
      }
    }

    var generator = makeGenerator.apply(this, arguments);
    if (isGenerator(generator)) {
      callback = continuer.bind(this, 'next');
      errback = continuer.bind(this, 'throw');
      return callback();
    } else {
      return Q.when(generator);
    }
  };
}
