require("digest/sha1");

Bundler.Definition = {

  build: function(gemfile, lockfile, unlock) {
    unluck = unlock || {};
    gemfile = Pathname.new(gemfile).expandPath();
    if (!gemfile.file()) {
      throw new GemfileNotFound(gemfile+' not found');
    }
    Dsl.evaluate(gemfile, lockfile, unlock);
  }
};

