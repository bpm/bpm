
BPM_PLUGIN.compileTransport = function(body, context, filename) {
  body = JSON.stringify("(function() { "+context.minify(body)+" })()\n");
  return "define_transport("+body+"), '"+context['package'].name+"', '"+context.moduleId+"', '"+filename+"');";
};

