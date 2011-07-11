require('bundler/dependency');

Bundler.Dsl = {
  evaluate: function(gemfile, lockfile, unlock) {
    var builder = new Bundler.Dsl();
    builder.instanceEval(Bundler.readFile(gemfile.toString()), gemfile.toString(), 1);
    builder.toDefinition(lockfile, unlock);
  }
};
