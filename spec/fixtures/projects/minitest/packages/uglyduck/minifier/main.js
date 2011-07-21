/*globals BPM_PLUGIN UGLYDUCK */

BPM_PLUGIN.minify = function(body, context, pathname) {
  var whatIsUglyDuck = 'undefined' === typeof UGLYDUCK ? '(main not loaded)' : UGLYDUCK;
  var whereIsUglyDuck = context.settings['uglyduck:where'] || '(build settings not found)'
  return "//MINIFIED START\nUGLY DUCK "+whatIsUglyDuck+whereIsUglyDuck+"\n"+body+"\n//MINIFIED END\n";
};
