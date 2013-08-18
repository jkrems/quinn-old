'use strict';

let wrapGenerator = require('./wrap-generator'),
    Q             = require('q');

module.exports = function lazyMap(collection, fn, bufferSize) {
  if (null == bufferSize) { bufferSize = 1; }

  let wrappedFn = wrapGenerator(fn);

  function* iterate() {
    let key, inputQueue = [], resultQueue = [];
    for (key in collection) {
      inputQueue.push(key);
    }

    let fillUpQueue = function() {
      // make sure resultQueue has at least bufferSize + 1 elements
      let diff = Math.max(0, (bufferSize - resultQueue.length + 1));
      let newResults = inputQueue.splice(0, diff).map(function(key) {
        return wrappedFn(collection[key], key, collection);
      });
      // add the new results to the end of the result queue
      resultQueue = resultQueue.concat(newResults);
    };
    fillUpQueue();

    while (resultQueue.length > 0) {
      let mapped = resultQueue.shift();
      fillUpQueue();
      yield mapped;
    }
  };
  // collection may be:
  // a) an array
  // b) an object
  // c) a generator
  let cType = Object.prototype.toString.call(collection).slice(8, -1);
  if (Array.isArray(collection)) {
    return iterate();
  } else if (cType === 'Generator') {
    // TODO: handle Generator
  } else if (typeof collection === 'object') {
    if (Q.isPromise(collection)) {
      return collection.then(function(resolved) {
        return lazyMap(resolved, fn, bufferSize);
      });
    }
    return iterate();
  }
  throw new Error(
    "Unsupported type of collection for lazyMap: " + typeof collection
  );
};
