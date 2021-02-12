#!/usr/bin/perl

# update.pl
# the purpose of this script is to
#   find new items
#   run IndexTextFile() on them
#   re-generate affected pages
#		via the task table

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

require './utils.pl';

# look for anything new in access log
system('./access.pl --all');

# index any files which haven't been indexed already
system('./index.pl --all');

# rebuild static html files if necessary
if (
	GetConfig('admin/pages/lazy_page_generation') &&
	GetConfig('admin/pages/rewrite') eq 'all' &&
	GetConfig('admin/php/enable')
) {
	#todo html_clean without disturbing site
} else {
	# regenerate all pages (may take a while)
	system('./pages.pl --all');
}

# build /compost and /index0.html pages
system('./pages.pl --index');

# update status of page queue
system('./query/page_touch.sh');

# update displayed timestamp
UpdateUpdateTime();

1;