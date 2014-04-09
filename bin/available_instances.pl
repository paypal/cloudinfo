#!/usr/bin/perl

use strict;
use Socket;
use DBI;
use Getopt::Long;
use FindBin;

my $conf_file = "$FindBin::Bin/../conf/cloud.cfg";
my $conf_ref = get_conf();
my %Conf = %$conf_ref;

my ($requested_aggregate, $flavor, $debug);
GetOptions( 'aggregate=s'   => \$requested_aggregate,
            'flavor=s'      => \$flavor,
            'debug'         => \$debug,
);

if (! defined $requested_aggregate) {
    $requested_aggregate = "General_Purpose";
}
if ( ! defined $flavor ) {
    print "Missing flavor\n";
    help();
    exit 1;
}

if ( ! $Conf{cpu_allocation_ratio} ) {
    $Conf{cpu_allocation_ratio} = 1;
}

if ( ! $Conf{ram_allocation_ratio} ) {
    $Conf{ram_allocation_ratio} = 1;
}

#################################################
my $dbh = DBI->connect("DBI:mysql:database=$Conf{NOVA_DB};host=$Conf{DB_HOST};port=$Conf{DB_PORT}", "$Conf{READONLY_USER}", "$Conf{READONLY_PASSWORD}",
               {'RaiseError' => 1 });

############################
# Get Flavor size
my %Flavor = ();

my $sql = qq[select memory_mb,vcpus,root_gb,ephemeral_gb from $Conf{NOVA_DB}.instance_types where name = '$flavor'];
print "Debug: SQL = $sql\n" if defined $debug;

my $sth = $dbh->prepare($sql) or die "Couldn't prepare query";
$sth->execute();
$sth->rows;
while (my @rows = $sth->fetchrow_array()) {
     $Flavor{memory} = $rows[0];
     $Flavor{cpus}   = $rows[1];
     $Flavor{disk}   = $rows[2] + $rows[3];
}
$sth->finish();
if ( keys %Flavor == 0 ) {
    print "Cannot find flavor: $flavor\n";
    $dbh->disconnect();
    exit 1;
}

print "Debug: FlavorMemory=$Flavor{memory} FlavorCPUs=$Flavor{cpus} FlavorDisk=$Flavor{disk}\n" if defined $debug;

#################################################
# Get Hypervisor info
my %Hypervisors = ();
my $sql;

if ( $Conf{OS_RELEASE} eq "Grizzly" ) {
    $sql = qq[select SUBSTRING_INDEX(hypervisor_hostname, '.', 1), IFNULL((select a.name from $Conf{NOVA_DB}.aggregate_hosts ah LEFT JOIN $Conf{NOVA_DB}.aggregates a ON a.id=ah.aggregate_id where SUBSTRING_INDEX(host, '.', 1) = SUBSTRING_INDEX(hypervisor_hostname, '.', 1) and a.name not like '%fz_%' and ah.deleted=0 and a.deleted=0), 'General_Purpose'), vcpus,vcpus_used,memory_mb,memory_mb_used,disk_available_least from $Conf{NOVA_DB}.compute_nodes where deleted = 0];
}
elsif ( $Conf{OS_RELEASE} eq "Folsom" and $Conf{aggregate_type} eq "availability_zone" ) {
    $sql = qq[select SUBSTRING_INDEX(cn.hypervisor_hostname,'.', 1), s.availability_zone,vcpus,vcpus_used,memory_mb,memory_mb_used,disk_available_least from compute_nodes cn LEFT JOIN services s ON cn.service_id=s.id where s.availability_zone != 'nova' and s.disabled = 0 and cn.deleted = 0];
}
else {
    print "Missing OS_RELEASE and/or aggregate_type in $conf_file\n";
    $dbh->disconnect();
    exit 1;
}

print "Debug: SQL = $sql\n" if defined $debug;

my $sth = $dbh->prepare($sql) or die "Couldn't prepare query";
$sth->execute();
$sth->rows;
while (my @rows = $sth->fetchrow_array()) {
     my $host = $rows[0];
     $Hypervisors{$host} = { name => $host, aggregate => $rows[1], cpus => $rows[2], cpus_used => $rows[3], memory => $rows[4], memory_used => $rows[5], disk_avail => $rows[6] };
     #print "$rows[0] : $rows[1] : $rows[2] : $rows[3] : $rows[4] : $rows[5] : $rows[6] : $rows[7] \n";
}
$sth->finish();

my %Aggregates = ();

for my $host ( keys %Hypervisors ) {
    if ( $requested_aggregate eq $Hypervisors{$host}{aggregate} or $requested_aggregate eq "all" ) {
        my $hv_aggregate = $Hypervisors{$host}{aggregate};
        #print "$Hypervisors{$host}{name} - $Hypervisors{$host}{cpus} - $Hypervisors{$host}{cpus_used} : R $Hypervisors{$host}{memory} - $Hypervisors{$host}{memory_used} : D: $Hypervisors{$host}{disk_avail}\n";
        my $cpu_avail = ( $Hypervisors{$host}{cpus} * $Conf{cpu_allocation_ratio} ) - $Hypervisors{$host}{cpus_used}; 
        my $memory_avail = ( $Hypervisors{$host}{memory} * $Conf{ram_allocation_ratio} ) - $Hypervisors{$host}{memory_used}; 
        my $disk_avail = $Hypervisors{$host}{disk_avail};
        #print "   Avail: cpu=$cpu_avail ram=$memory_avail disk=$disk_avail\n";

        my $full = 0;
        my $avail_instances = 0; 
        while ( $full == 0 ) {
            if ( $cpu_avail > $Flavor{cpus} and $memory_avail > $Flavor{memory} and $disk_avail > $Flavor{disk} ) {
                $cpu_avail = $cpu_avail - $Flavor{cpus};
                $memory_avail = $memory_avail - $Flavor{memory};
                $disk_avail = $disk_avail - $Flavor{disk};
                $avail_instances++;      
            }
            else {
                $full = 1;
            }
        }
        $Aggregates{$hv_aggregate} = $Aggregates{$hv_aggregate} + $avail_instances;

        print "Debug:  $Hypervisors{$host}{name}  AvailableInstances=$avail_instances\n" if defined $debug;
    }
}
$dbh->disconnect();

for my $hv_aggregate (keys %Aggregates) {
     print "$hv_aggregate=$Aggregates{$hv_aggregate}\n";
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
    print "This script prints the number of available instances for defined flavor for defined aggregate\n";
    print "Usage: $0 --aggregate <aggregate name> --flavor <flavor name>\n";

}
