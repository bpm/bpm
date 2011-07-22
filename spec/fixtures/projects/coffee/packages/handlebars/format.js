
exports.compileFormat = function(body, context, filename) {
  var runtime = typeof RUNTIME === undefined ? '(NO runtime)' : RUNTIME;
  return "HANDLEBARS("+body+" "+runtime+")";
};

