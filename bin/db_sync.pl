#!/usr/bin/perl

use strict;
use File::Basename;
use DBI;
use Getopt::Long;
use FindBin;
use YAML::XS qw/LoadFile/;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

my $DBConf = LoadFile("$FindBin::Bin/../conf/db_sync.yaml");
my %DBConfig = %$DBConf;
my $conf_file     = "$FindBin::Bin/../conf/db_sync.cfg";
my $last_run_file = "$FindBin::Bin/../last_run";
my $conf_ref = get_conf();
my %Conf = %$conf_ref;

PidFile("create");

my $debug;
GetOptions( 'debug' => \$debug,
);


#Connect to Destination DB
my $tdsn = "DBI:mysql:host=$Conf{tdb_host};port=$Conf{tdb_port}";
my $tdbh = DBI->connect($tdsn, $Conf{tdb_user}, $Conf{tdb_password},
                       {'RaiseError' => 1 });


###################################################################################################
# Check whether target database,table,columns exist
for my $db_host (keys %DBConfig ) {
    for my $source_db (keys %{ $DBConfig{$db_host} }) {
        next if $source_db eq "db_object";
        my $target_db = $source_db;
        if ( $DBConfig{$db_host}{$source_db}{target_db} ) {
            $target_db = $DBConfig{$db_host}{$source_db}{target_db};
        }
        print "  Checking source_db: $source_db and  target_db: $target_db\n";
        for my $table ( keys %{ $DBConfig{$db_host}{$source_db} }) {
            if ( $table eq "target_db" ) {
                next;
            }
            my $columns = $DBConfig{$db_host}{$source_db}{$table}{columns};
            my $sel_columns = $columns;
            $sel_columns =~ s/binary/`binary`/;
            $sel_columns =~ s/key/`key`/;
            my $sql = qq[select $sel_columns from ${target_db}.${table} where 1 = 0];
            if ( ! TargetTableExists($sql) ) {
                print "Trying to create target table: $target_db.$table ......\n";
                CreateTargetTable($db_host,$source_db,$target_db,$table,$columns);
                if ( ! TargetTableExists($sql) ) {
                    print "Failed to create target $target_db.$table ($columns). \n";
                    print "Make sure $target_db exists and user $Conf{tdb_user} has permissions.\n";
                    $tdbh->disconnect();
                    exit 1;
                }
            }
        }
    }
}
###################################################################################################
# Get DB Hosts
for my $db_host (keys %DBConfig ) {
    my $db_port     = $DBConfig{$db_host}{db_object}{port};
    my $db_user     = $DBConfig{$db_host}{db_object}{user};
    my $db_password = $DBConfig{$db_host}{db_object}{password};

    print "Connecting to $db_host ....\n";
    print "Debug: host=$db_host port=$db_port user=$db_user password=$db_password \n" if ($debug);
    my $dbh = DBI->connect("DBI:mysql:host=$db_host;port=$db_port", "$db_user", "$db_password",
              {'RaiseError' => 1 });

    # Get DB names
    for my $source_db ( keys %{ $DBConfig{$db_host} }) {
        next if $source_db eq "db_object";
        my $target_db = $source_db;
        if ( $DBConfig{$db_host}{$source_db}{target_db} ) {
            $target_db = $DBConfig{$db_host}{$source_db}{target_db};
        }

        print "  Syncing database: $source_db to target_db: $target_db\n";
        # Get tables
        for my $table ( keys %{ $DBConfig{$db_host}{$source_db} }) {
            if ( $table eq "target_db" ) {
                next;
            }

            print "     Syncing table: $table\n";
            my $columns = $DBConfig{$db_host}{$source_db}{$table}{columns};
            my $where = "";
            if ($DBConfig{$db_host}{$source_db}{$table}{where} ne "" ) {
               $where = qq[where $DBConfig{$db_host}{$source_db}{$table}{where}];
            }
            $columns =~ s/\s+//;
            my @Columns  = split(/,/,$columns);
            my $sel_columns = $columns;
            $sel_columns =~ s/binary/`binary`/;
            $sel_columns =~ s/key/`key`/;
            my $sql = qq[select $sel_columns from ${source_db}.${table} $where];
            print "Debug: SQL = $sql\n" if ($debug);

            my $target_sql = qq[select $sel_columns from ${target_db}.${table}];
            ###################################
            my %TargetRecords = map { shift @$_, [ @$_ ]} @{$tdbh->selectall_arrayref($target_sql)};
            my %Records = map { shift @$_, [ @$_ ]} @{$dbh->selectall_arrayref($sql)};


            ################################################################
            # Delete Cloudinfo records which have been deleted from OpenStack DB
            for my $key ( keys %TargetRecords ) {
                if ( ! $Records{$key} ) {
                     my $TargetRow = $TargetRecords{$key};
                     my $sql = qq[delete from ${target_db}.${table} where @Columns[0] = '$key'];
                     UpdateTargetDB("delete", $sql);
                }
            }

            ################################################################
            # Update/Insert  OpenStack -> Cloudinfo
            for my $key ( keys %Records ) {
                my $Row = $Records{$key};
                if ( $TargetRecords{$key} ) {
                    my $md5sum = md5_hex(join($", @$Row));

                    my $TargetRow = $TargetRecords{$key};
                    my $target_md5sum = md5_hex(join($", @$TargetRow));

                    if ( $md5sum ne $target_md5sum ) {
                         #Updat record
                         my $values = qq['$key','];
                         for (@$Row) { s/'/''/g };   # Replacing single quote with double
                         $values .= join("','", @$Row);
                         $values .= "'";
                         my $sql = qq[delete from ${target_db}.${table} where @Columns[0] = '$key'];
                         my $sql2 = qq[insert into ${target_db}.${table} values ($values)];
                         print "Debug: Updating $table with $values\n" if ($debug);
                         UpdateTargetDB("update", $sql, $sql2);
                    }
                }
                else {
                    #Insert record
                    my $values = qq['$key','];
                    for (@$Row) { s/'/''/g };   # Replacing single quote with double
                    $values .= join("','", @$Row);
                    $values .= "'";
                    my $sql = qq[insert into ${target_db}.${table} values ($values)];
                    UpdateTargetDB("insert", $sql);
                }

            }
            ###################################

        }
    }

    $dbh->disconnect();
}
$tdbh->disconnect();

PidFile("delete");

my $timestamp = time();
open my $LAST_RUN, '>', "$last_run_file" or die "Cannot create $last_run_file: $!\n";
print $LAST_RUN $timestamp;
close $LAST_RUN;

###########################################
sub TargetTableExists {
    my $sql = shift;
    eval {
        local $tdbh->{PrintError} = 0;
        local $tdbh->{RaiseError} = 1;
        $tdbh->do($sql);
    };
    return 1 unless $@;
    return 0;
}
###########################################
sub UpdateTargetDB {
    my $action = shift;
    my $sql    = shift;
    my $sql2   = shift;

    if ( $action eq "update" ) {
        print "Debug SQL = $sql\n" if ($debug);
        print "Debug SQL = $sql2\n" if ($debug);
        $tdbh->do($sql);
        $tdbh->do($sql2);
    }
    elsif ( $action eq "insert" ) {
        print "Debug SQL = $sql\n" if ($debug);
        $tdbh->do($sql);
    }
    elsif ( $action eq "delete" ) {
        print "Debug SQL = $sql\n" if ($debug);
        $tdbh->do($sql);
    }

}
#############################################
sub CreateTargetTable {
    my $sdb_host = shift;
    my $source_db   = shift;
    my $target_db   = shift;
    my $table       = shift;
    my $columns     = shift;
    $columns =~ s/\s+//g;
    my @Columns     = split(/,/,$columns);

    my $sdb_port     = $DBConfig{$sdb_host}{db_object}{port};
    my $sdb_user     = $DBConfig{$sdb_host}{db_object}{user};
    my $sdb_password = $DBConfig{$sdb_host}{db_object}{password};

    print "sdb_user: $sdb_user ; sdb_password = $sdb_password ; sdb_port = $sdb_port\n" if ($debug);
    my $sdsn = "DBI:mysql:host=$sdb_host;port=$sdb_port";
    my $sdbh = DBI->connect($sdsn, $sdb_user, $sdb_password,
                       {'RaiseError' => 1 });

    my $sth = $sdbh->column_info( undef, $source_db, $table, '%');
    my $col_names = $sth->{NAME_uc};
    my %row; $sth->bind_columns(\@row{@$col_names});

    my $column_info;
    my %ColumnInfo = ();
    while ($sth->fetch) {
        $ColumnInfo{$row{COLUMN_NAME}} = $row{MYSQL_TYPE_NAME};
    }
    for my $column (@Columns) {
       $column_info .= " $column $ColumnInfo{$column}, ";
    }
    $column_info =~ s/,\s+$//;
    $column_info =~ s/binary/`binary`/;
    $column_info =~ s/key/`key`/;
    my $sql;
    if ( $column_info =~ m/text/ ) {
       $sql = qq[create table ${target_db}.${table} ($column_info)];
    }
    else {
       $sql = qq[create table ${target_db}.${table} ($column_info) ENGINE = MEMORY];
    }
    $sdbh->disconnect();

    print "Debug: $sql\n" if ($debug);
    $tdbh->do($sql);
}
#############################################
sub PidFile {
    my $pf_action = shift;
    my $pid_dir = dirname($Conf{pidfile});
    if (! -d $pid_dir ) {
        mkdir $pid_dir, 0755;
    }
    if ( ! $Conf{pidfile}) {
        print "Error: Missing pidfile in conf file. \n";
        exit 1;
    }
    if ( $pf_action eq "create" ) {
        if ( -f $Conf{pidfile} ) {

            my $pid = `cat $Conf{pidfile}`;
            chomp($pid);
            if ( ! -d "/proc/${pid}" ) {
                system("/bin/rm $Conf{pidfile}");
            }
            else {
               print "$0 is already running. $Conf{pidfile} exists. \n";
               exit;
            }
        }
        if (open(PID, ">$Conf{pidfile}")) {
            print PID "$$\n";
            close PID;
        }
        else {
            print("Error: Could not open pidfile: $Conf{pidfile} - $! \n");
            exit;
        }
   }
   elsif ( $pf_action eq "delete" ) {
       system("/bin/rm $Conf{pidfile}");
       if ( -f $Conf{pidfile} ) {
           print "Error: Could not remove $Conf{pidfile}\n";
           exit;
       }
   }
}
#############################################
sub get_conf {
   my %conf = ();
   my @CONF = `cat $conf_file`;
   foreach my $line (@CONF) {
      chomp($line);
      if ( $line =~ m/(.*)=(.*)/ ) {
          my $conf_key = $1;
          my $conf_value = $2;
          $conf_value =~ s/^"//;
          $conf_value =~ s/"$//;
          $conf{$conf_key} = $conf_value;
      }
   }
   return (\%conf);
}
