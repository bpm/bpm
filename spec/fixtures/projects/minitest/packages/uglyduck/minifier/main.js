/*globals BPM_PLUGIN UGLYDUCK */

BPM_PLUGIN.minify = function(body, pkg, moduleId, pathname) {
  var whatIsUglyDuck = 'undefined' === typeof UGLYDUCK ? '(main not loaded)' : UGLYDUCK;
  return "//MINIFIED START\nUGLY DUCK "+UGLYDUCK+"\n"+body+"\n//MINIFIED END\n";
};
