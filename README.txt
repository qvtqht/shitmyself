SHITMYSELF
==========
Message board for hackers and friends which aims to please.


PHILOSOPHY
==========
Be kind and polite to all beings whenever possible.
Readable source code for clarity and honesty.
Aim to support every device, browser, and user.
Do what user asks, wants, or is in their best interest.
Don't ask or demand user to do anything they don't want.
Try to make user comfortable. Do not bother user with trivia.
Tell the truth, the whole truth, and nothing but the truth.
Whenever you find yourself on the side of majority, pause and reflect.
You become responsible, forever, for what you have tamed.

   * * *

WHY USE THIS?
=============
Below is an outline of reasons you would want to use sHiTMyseLf.
I have made an attempt to start with less technical reasons first.
As you go along, it gets more technical. Technically.

Empowering
==========
User "account", aka private key, remains in user's possession and control.
Identity can be used across multiple servers without "federation".
Registration is not required, and registering does not require email.
Designed to allow the user to know who is operating the site.

Provable
========
Provable reliability of information integrity with digital signatures.
Provable consensus and voting results -- full transparency.
Provable privacy by allowing end user to control physical access to data.

Portable
========
All forum data is stored as text files, improving ability to archive.
Data is housed by service provider without lock-down.

Customizable
============
Custom themes and appearance using simple commands (like Myspace or Tumblr)

Durable/Decentralized
=====================
All data can be downloaded and replicated, in entirety or in segments.
Can be cloned and re-hosted, with portable user accounts usable across all copies.

Accessible
==========
Accessible to all beings, regardless of hardware, software, or configuration.
Tries very hard to accommodate every known and testable client.
Tested with hundreds of different browsers, devices, and configurations.
Full support for text-mode, no-JS, screen-readers, mouse-free, etc.
Registration is optional, unless operator changes default configuration.
Easier to access via telnet than with most websites.

Securable
=========
Can be operated as static HTML for a smaller attack surface.
JavaScript is also an optional module and optional for clients.

Convenient
==========
Optional PHP and SSI modules for more convenient usage.
Optional client-side JS module for easier client signatures.

Friendly, Compatible, Accessible
================================
Modular interface shows only the basics for beginners, more options later.
Tested thoroughly by many devices, configurations, platforms, browsers, users.
Tested for accessibility by vision, mobility, and connectivity impaired users.
Tested with Mosaic, Netscape, IE, Opera, iOS, Android, Lynx, w3m, and more.
Supports all web servers which can write standard access.log format.

Art-Friendly
============
Text-art is accommodated with a monospace font and preserving whitespace layout.
Compatible with historic browsers to allow time-period-accurate installations.

Transparent
===========
Everything posted to community is viewable and verifiable.
Voting logs are transparent, auditable, and trustable (Kevin Bacon)
Meta-moderation is possible by voting on votes, and so on.
Best content (and friends) for each user can be found with vote comparison.
Ballot stuffing and other abuse is detectable with data analysis.
Validation chain prevents tampering with item posting timestamps.
Items can be deleted by operator, but trace remains in timestamp log.

Resilient
=========
Avoid spam target by fine-tuning access.
Avoid advertising by avoiding over-growth.
User-centric operation allows easy migration in case of instance changes.

   * * *

SUPPORTED ENVIRONMENTS
======================
As stated above, sHiTMyseLf aims to please, and make do with whatever you got.

Frontend Tested With:
=====================
Mozilla Firefox
Chrome
Chromium
Bromite (Android)
Samsung Browser (Android)
qutebrowser
Links
Lynx
w3m
Mosaic 1*, 2*, 3*
Opera 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
Netscape 2*, 3, 4
Internet Explorer 2*, 3, 4, 5.5, 6, 7, 8, 9, 10, 11
curl
wget
NetSurf
OffByOne
Safari iOS 7, 8, 9, 10, 11, 12, 13
Safari Windows 1, 2, 3, 4, 5
Some kind of in-TV browser with no monospace font!

* Some browsers, marked with *, need extra setup.
Not every feature is supported by every browser.
Not every minor version was tested.
Many browsers support very few features.
However, with prior knowledge of system,
Reading, writing, voting was done successfully.

   * * *

Frontend Testers Wanted:
========================
WorldWideWeb
Amaya
Telnet
iOS Safari older than 7.x
Android Browser
any other browsers not mentioned

Building/Backend Tested With:
=============================
Fedora
Mint
Ubuntu
Debian
DreamHost
Mac OS X
macOS

Installation Testers Wanted:
============================
FreeBSD
OpenBSD
NetBSD
Windows
Cloud services

   * * *

STACK DESCRIPTION
=================
Hopefully this is reasonably easy to acquire.

Required
========
Web browser or HTML viewer
Text editor
POSIX/GNU/*nix
Perl 5.010+
git
sqlite3

Perl Modules
============
URI::Encode
URI::Escape
HTML::Parser
Digest::MD5
Digest::SHA1
File::Spec
DBI
DBD::DBSQLite

Optional Components
===================
* Web Server
* access.log
* zip
* gpg
* ImageMagick
* SSI
* PHP

   * * *

PACKAGE INSTALLATION
====================
No third-party package manager should be necessary.

Ubuntu, Debian, Mint, Trisquel, Ubuntu, and other apt-based
==========================================================================
# apt-get install liburi-encode-perl libany-uri-escape-perl libhtml-parser-perl libdbd-sqlite3-perl libdigest-sha-perl sqlite3 gnupg gnupg2 imagemagick php-cgi zip

Redhat, CentOS, Fedora, and other yum-based
============================================================
# yum install perl-Digest-MD5 perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite perl-URI-Encode perl-Digest-SHA1 sqlite gnupg gnupg2 perl-Devel-StackTrace perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite lighttpd-fastcgi ImageMagick php-cgi

   * * *

INSTALLATION FOR LOCAL TESTING
==============================
$ cd ~
$ git clone ...
$ cd ~/shitmyself
$ ./install_os_packages
$ ./build.pl

TROUBLESHOOTING
===============
If you get an error about the version of SQL library during build, do this:
   $ cd ~/shitmyself
   $ rm -rf ./lib/

LOCAL ADMINISTRATION
====================
Publish an item with some text:
   $ echo "hello, world" > html/txt/hello.txt
   $ ./update.pl

Publish profile:
   $ gpg --armor --export > ./html/txt/my_profile.txt
   $ ./update.pl

Sign and publish some text:
   $ echo "hello, world" > my_post.txt
   $ gpg --clearsign my_post.txt > ./html/txt/my_post.txt

Become official admin:
   $ gpg --armor --export > ./admin.key
   $ ./update.pl

Rebuild frontend if you changed a setting:
   $ ./generate.pl

View the page generation queue:
   $ ./query/page_touch.sh

Archive all the content and start afresh:
   $ ./archive.pl


DEPLOYMENT USING APACHE, LIGHTTPD, OR NGINX
===========================================
WARNING: THESE INSTRUCTIONS ASSUME YOU KNOW WHAT YOU'RE DOING.
   Do not deploy unless you know what you're doing.
   This code has not been audited, nor thoroughly tested.

Other Asumptions
================
Assuming you already installed as instructed above.
Assuming "." is project directory
Assuming "access.log" is NCSA standard
Assuming platform is GNU/Linux

If you're using the access.log update methods
=============================================
1. Symlink log/access.log to wherever your access log lives:

   $ ln -s ./log/access.log /var/log/www/access.log

   Access log is read non-destructively, and should be rotated.
   Hashed lines are stored in log/processed.log after done.

2. Symlink html root to html/

   $ rmdir /var/www/html
   $ ln -s ./html /var/www/html

3. Depending which modules are you are planning to use, set the following settings.

   Each setting is its own plaintext file containing 0 or 1.
   Other values may resolve unpredictably.
   Removing the file will result in it being reset to default.
   Defaults live in similar structure under ./default/ directory.
   Note: PHP and SSI may not work together.

   PHP module: ./config/admin/php/enable
   SSI module: ./config/admin/ssi/enable
   Frontend JavaScript module: ./config/admin/js/enable
   Images module: ./config/admin/image/enable

4. If you are using neither PHP, nor SSI, updating site requires running update.pl

   You can add it to your crontab if you like.
   You can limit the script's runtime:
      ./config/admin/update/limit_time
      contains a limit on how long this script will run, in seconds

Note
====
Not using PHP and SSI can lower the attack surface of your installation.
   The tradeoff is convenience and usability:
      Users won't see their actions take effect right away.

UPGRADING
=========
Upgrade process duration is proportionate to the amount of data already stored.
New versions may introduce incompatibilities, but system should remain operable.
Eventually, faster and more efficient upgrading should be possible.

Upgrade the code, keep the data and config, and rebuild everything else:

$ git pull --all
$ ./clean.sh          # remove html files, cache, index
$ ./build.pl          # after this, site should be up and accessible
$ ./update.pl --all   # re-import everything and rebuild site

ROLLBACK
========
Installing a version different from most recent:

$ git checkout 0123abcd
$ ./clean.sh
$ ./build.pl
$ ./update.pl --all

repl.it development
===================
In testing, largely working except for the lack of DBD::DBSQLite library

KNOWN ISSUES
============
See known.txt

CONFIG and TEMPLATES
====================
Both configuration and various templates are stored in...

./config/
	Edit configuration here
	Only values looked up at least once appear here
	If this is empty, run ./build.pl

./default/
	Do NOT edit this for configuring
	May be overwritten during upgrade
	Part of the repository
	This is for developer
	Provides defaults
	Same structure as config above

Most values are 0/1 boolean or one-liners
Config is handled using one file per setting.
To change a setting, edit the file in config/
config/admin/debug is special, delete file to 0













































































































































































































































































































