
exports.compileFormat = function(strings) {
  // basically, the strings is like a simplified form of JSON.
  // We should probably replace this with a real parser at some point.
  return "return {"+strings+"};";
};
