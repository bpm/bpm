
exports.compileTransport = function(body, pkg, moduleId) {
  return "define_transport(function() {\n"+body+"\n});";
};

