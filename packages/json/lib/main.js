
exports.compileFormat = function(json) {
  return 'return '+json+';';
};

// TODO: make these work on browsers w/o JSON.

exports.parse = function(str) {
  return JSON.parse(str);
};

exports.stringify = function(obj) {
  return JSON.stringify(obj);
};
