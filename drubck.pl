#!/usr/bin/perl

#use warnings;
use POSIX qw/strftime/;
use Term::ReadKey;

$backup_folder = "/home/odorf/shared/fedora/code/drush-backup/";		#change this to the absolute path where your backups are to be stored
$apache_root = "/var/www/html/";								#change this to the absolute path of your apache root directory

#======globals============

#======subs============

sub checkIfRoot{
	printf("%-70s", "Checking privileges");
	my $whoAmIHome = $ENV{HOME};
	chomp($whoAmIHome);
	if($whoAmIHome =~ /^\/root$/){
		printf("%5s\n", "[ok]");
		return 1;
	}
	else{
		printf("%5s\n", "[error]");
		print "\tYou have no privileges with this account. Please run the script as root!\n";
		return 0;
	}
}

sub locatedDrupalDatabases{
	my $databasesLocated;
	my @locatedSettingsphp = `find /var/www/html/ -name 'settings.php'`;
	foreach $locatedSetting (@locatedSettingsphp){
		chomp($locatedSetting);
		open SETTINGPHP, "<$locatedSetting";
		my @contentsOfSettingphp = <SETTINGPHP>;
		my $lineOfSettingphp;
		foreach $lineOfSettingphp (@contentsOfSettingphp){
			if($lineOfSettingphp =~ /^\s+'database' => '(.*)'.*/){
				$databasesLocated .= "$1 ";
			}
		}
		$lineOfSettingphp = "";
		@contentsOfSettingphp = ();
		close(SETTINGPHP);
	}
	chop($databasesLocated);
	return $databasesLocated;
}

sub help{
	printf("%-20s%-60s\n", "--help", "print this help form");
	printf("%-20s%-60s\n", "--install", "install the script to /bin/ folder, run as root");
	printf("%-20s%-60s\n", "--uninstall", "removes /bin/drubck symbolic link");
	printf("%-20s%-60s\n", "-b", "creates an apache server, root directory, full backup, with drupal databases");
	printf("%-20s%-60s\n", "-r", "prints available backups, and lets you restore a selected one, by WIPING ALL apache server files beforehand.");
}


#======subs==================

if((defined $ARGV[0]) && ($ARGV[0] =~ /^--install/)){
	if(&checkIfRoot == 0){exit;}
	$current_installation_dir = $ENV{PWD};
	system("ln -s $current_installation_dir/$0 /bin/drubck");
}

elsif((defined $ARGV[0]) && ($ARGV[0] =~ /^--uninstall/)){
	if(&checkIfRoot == 0){exit;}
	unlink("/bin/drubck");				#check if deletion works, otherwise use system rm -rf
}

elsif((defined $ARGV[0]) && ($ARGV[0] =~ /^--help/)){
	&help();
}

elsif((defined $ARGV[0]) && ($ARGV[0] =~ /^-b/)){
	if(&checkIfRoot == 0){exit;}
	$current_drupal_databases = &locatedDrupalDatabases();
	print "backup comment: "; chomp($backup_comment = <STDIN>);
	print "mysql root password: "; ReadMode('noecho'); chomp($mysql_password = ReadLine(0)); ReadMode('normal');
	$filename = strftime "%Y%m%d%H%M%S", localtime;
	$nice_filename = strftime "%Y-%m-%d %H:%M:%S", localtime;
	$sql_filename = $apache_root . $filename . ".sql";
	system("mysqldump -u root -p$mysql_password --databases $current_drupal_databases > $sql_filename");
	print "\nStoring...";
	$tarball_name = $backup_folder . $filename . ".tar.bz2";
	system("tar -cjpf $tarball_name -C $apache_root ./");
	open BACKUPSLIST, ">>$backup_folder" . "list";
	print BACKUPSLIST "$filename\t$nice_filename\t$backup_comment\n";
	close(BACKUPSLIST);
	print "\n";
	unlink($apache_root . "$filename.sql");
}

elsif((defined $ARGV[0]) && ($ARGV[0] =~ /^-r*/)){
	if(&checkIfRoot == 1){exit;}
	$q = 1;
	open BACKUPSLISTSHOW, "<$backup_folder" . "list";
	while(<BACKUPSLISTSHOW>){
		if($_ =~ /^(\d+)\t(.*)\t(.*)/){
			print "$q:\t$2\t$3\n";
			$list_of_backups[$q-1] = $1;
			$q++;
		}
	}
	close(BACKUPSLISTSHOW);
	print "\nbackup to restore: "; chomp($backup_to_restore = <STDIN>);
	$tarball_timestamp = $list_of_backups[$backup_to_restore-1] ;
	print "mysql root password: "; ReadMode('noecho'); chomp($mysql_password = ReadLine(0)); ReadMode('normal');
	$to_del_from_apache = $apache_root . "*";
	system("rm -rf $to_del_from_apache");
	$tarball_to_restore = $backup_folder . $tarball_timestamp . ".tar.bz2";
	system("tar -xjpf $tarball_to_restore -C $apache_root");
	$mysql_to_restore = $apache_root . $tarball_timestamp . ".sql";
	print "\n";
	system("mysql -u root -p$mysql_password < $mysql_to_restore");
	system("service httpd restart");
}

else{
	&help();
}