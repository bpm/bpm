
BPM_PLUGIN.compileTransport = function(body, context, filename) {
  return "define_transport(function() {\n"+body+"\n}), '"+context['package'].name+"', '"+context.moduleId+"', '"+filename+"');";
};

