
// to compile a format return a string of JavaScript that can be eval'd for 
// the module.  This way later the format compiler can be removed by the 
// optimizer.
exports.compileFormat = function(str) {
  return 'return '+JSON.stringify(str)+';';
};

