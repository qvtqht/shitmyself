localdev:
	./build.pl
	echo 1 > config/admin/lighttpd/enable
	./build.pl
	xdg-open "http://localhost:2784/"	
