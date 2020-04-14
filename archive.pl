#!/usr/bin/perl

my $date = `date +%s`;
chomp $date;

if (!-e 'archive') {
	mkdir 'archive';
}

if (-d 'archive') {
	system("mkdir archive/$date");
	system("mv html archive/$date");
	system("cp -r config archive/$date");
	system("mv log archive/$date");
	system("rm cron.lock");

	system("mkdir html");
	system("mkdir html/txt");
	system("mkdir html/image");
	system("mkdir html/thumb");
	system("echo \"archived at $date\" > html/txt/archived_$date\.txt");
}
