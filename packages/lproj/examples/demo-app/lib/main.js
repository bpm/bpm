/*globals lproj */

require('lproj');
require('jquery');

var loc = lproj(require); // activate lproj
$('h1').text(loc('_Hello World'));
