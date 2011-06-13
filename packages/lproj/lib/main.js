/*globals lproj ENV */ 

// NOTE: expects to be called with 'this' equal to require
function lookupString(moduleId, string, lang) {
  
  // get the strings...
  moduleId = moduleId ? this.normalize(moduleId) : this.id;
  var packageId = moduleId.slice(0, moduleId.indexOf('/'));
  var strings   = this.loc(packageId+'/~lproj/localized', lang);

  return strings && strings[string] ? strings[string] : string;
}

/**
  Modifies the passed require function to support localization.  Also 
  generates a 'loc' function, which can be used to localize strings.
*/
lproj = function(req) {
  
  if (req._lproj) return req._lproj; // make indempotent
  
  var _exists = req.exists,
      _async  = req.async,
      _normalize = req.normalize;

  req.language = ENV.LANG || 'en-US';
  req.defaultLanguage = 'en-US';
  
  function locit(req, id, lang) {
    var working, langs, ret, idx, len;

    id = _normalize.call(req, id);
    if (!id.match(/^[^\/]+\/~lproj\//)) return id; // nothing to do

    if (!lang) lang = req.language ;
    langs = [lang];
    if (lang.indexOf('-')>=0) langs.push(lang.slice(0, lang.indexOf('-')));
    if (req.defaultLanguage !== lang) {
      lang = req.defaultLanguage;
      langs.push(lang);
      if (lang.indexOf('-')>=0) langs.push(lang.slice(0, lang.indexOf('-')));
    }
    
    len = langs.length;
    for(idx=0;idx<len; idx++) {
      working = id.replace('/~lproj', '/~'+langs[idx]+'.lproj');
      if (_exists.call(req, working)) return working;
    }

    return id;
  }
  
  // upgrade require
  req.loc = function(id,lang) { return this(locit(this, id, lang)); };
  
  req.exists = function(id, lang) { 
    return _exists.call(this, locit(this, id, lang));
  };
  
  req.async = function(id, lang, callback) {
    if (!callback && ('function' === typeof callback)) {
      callback = lang;
      lang = null;
    }
    return _async.call(this, locit(this, id, lang), callback);
  };
  
  req.normalize = function(id, lang) {
    return locit(this, id, lang);
  };  

  // add string support
  req.string = lookupString;
  req._lproj = function(str, lang) { return req.string(null, str, lang); };
  return req._lproj;
};

return lproj; 
