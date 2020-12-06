clean:
	./clean.sh
	
local:
	./build.pl
	echo 1 > config/admin/lighttpd/enable
	./lighttpd.pl
	xdg-open "http://localhost:2784/"
