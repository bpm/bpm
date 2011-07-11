
BPM_PLUGIN.compileTransport = function(body, pkg, moduleId, filename) {
  return "define_transport(function() {\n"+body+"\n}), '"+pkg.name+"', '"+moduleId+"', '"+filename+"');";
};

