#!/usr/bin/perl

use strict;
use Socket;
use DBI;
use Getopt::Long;
use FindBin;

my $conf_file = "$FindBin::Bin/../conf/cloud.cfg";
my $conf_ref = get_conf();
my %Conf = %$conf_ref;

my ($subnet,$debug);
GetOptions( 'subnet=s'   => \$subnet,
            'debug'      => \$debug,
);


if (! defined $subnet) {
    help();
    print "\nMissing subnet\n";
    exit 1;
}

my $total_ips = 0;

##############################################

my $dbh = DBI->connect("DBI:mysql:database=$Conf{NOVA_DB};host=$Conf{DB_HOST};port=$Conf{DB_PORT}", "$Conf{READONLY_USER}", "$Conf{READONLY_PASSWORD}",
               {'RaiseError' => 1 });

my $sql = qq[select avail.first_ip, avail.last_ip from $Conf{QUANTUM_DB}.ipavailabilityranges avail LEFT JOIN $Conf{QUANTUM_DB}.ipallocationpools pool on pool.id = avail.allocation_pool_id LEFT JOIN $Conf{QUANTUM_DB}.subnets sn on pool.subnet_id = sn.id where sn.name = '$subnet'];
print "Debug: SQL = $sql\n" if defined $debug;

my $sth = $dbh->prepare($sql) or die "Couldn't prepare query";
$sth->execute();
$sth->rows;
while (my @rows = $sth->fetchrow_array()) {
     my $first_ip = dot2int($rows[0]);
     my $last_ip = dot2int($rows[1]);
     $total_ips = ($total_ips + ($last_ip - $first_ip) + 1 );
}
$sth->finish();
$dbh->disconnect();

print "$total_ips\n";

#################################################
sub dot2int {
    my $address = pop;
    my @bytes;
    while ($address =~ /(\d+)/g) {
        push @bytes,$1
    }
    return unpack('N',pack('C*',@bytes));
}
#################################################
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
#################################################
sub help {
    print "This script prints the number of available IPs of the specified subnet\n\n";
    print "Usage: $0 --subnet <subnet name>\n";
    
}
