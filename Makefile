clean:
	./clean_dev.sh
	
local:
	./build.pl
	./lighttpd.pl
	xdg-open "http://localhost:2784/"
