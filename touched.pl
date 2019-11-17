use strict;

require './utils.pl';
require './sqlite.pl';
require './index.pl';
require './access.pl';
require './pages.pl';

my $pagesProcessed;
$pagesProcessed = BuildTouchedPages();

WriteLog("Pages processed: $pagesProcessed");
print("Pages processed: $pagesProcessed\n");