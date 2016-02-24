#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;
use FindBin;


my $conf_file = "$FindBin::Bin/../conf/cloud.cfg";
my $conf_ref = get_conf();
my %Conf = %$conf_ref;

my ($host, $uuid, $hostname, $tenant, $state, $fields, $all_tenants, $help);
GetOptions( 'host=s'     => \$host,
            'hostname=s' => \$hostname,
            'uuid=s'     => \$uuid,
            'tenant=s'   => \$tenant,
            'state=s'    => \$state,
            'fields|f=s' => \$fields,
            'all-tenants' => \$all_tenants,
            'help|h'      => \$help,
);

my @Fields = ("uuid","hostname","host","tenant","ip","state","created_at","image_name");
print "\n";
if ( $help ) {
   help();
   exit;
}

my $where = "";
    if ( defined $uuid ) {
        $where .= qq[ where uuid = "$uuid"];
    }
    elsif ( defined $hostname ) {
        $where .= qq[ where display_name = "$hostname"];
    }
    elsif ( $tenant and ! $all_tenants ) {
        $where .= qq[ where tenant = "$tenant"];
        print "Showing instances in project: $tenant\n";
    }
    else {
        print "Showing instances for all projects\n";
    }


if ( defined $fields ) {
   @Fields = split(/,/,$fields);
}


my $sql = qq[select uuid, display_name, host, tenant, fixed_ip, cell, vm_state, created_at, image_name FROM $Conf{CLOUDINFO_DB}.instances $where order by created_at];

my $dbh = DBI->connect("DBI:mysql:database=$Conf{CLOUDINFO_DB};host=$Conf{CLOUDINFO_HOST};port=$Conf{CLOUDINFO_PORT}", "$Conf{CLOUDINFO_USER}", "$Conf{CLOUDINFO_PASSWORD}",
       {'RaiseError' => 1 });


my $sth = $dbh->prepare($sql) or die "Couldn't prepare query";
$sth->execute();
$sth->rows;
while (my @rows = $sth->fetchrow_array()) {
  my $uuid                    = $rows[0];
  my %Records = ();
  $Records{$uuid}{hostname}   = $rows[1];
  $Records{$uuid}{host}       = $rows[2];
  $Records{$uuid}{tenant}     = $rows[3];
  $Records{$uuid}{ip}         = $rows[4];
  $Records{$uuid}{cell}       = $rows[5];
  $Records{$uuid}{state}      = $rows[6];
  $Records{$uuid}{created_at} = $rows[7];
  $Records{$uuid}{image_name} = $rows[8];
  my $counter = 0;
  for my $field ( @Fields ) {
      if ( $counter != 0 ) {
            print "| ";
      }
      if ( $field eq "uuid" ) {
            print "$uuid ";
      }
      else {
            print "$Records{$uuid}{$field} ";
      }
      $counter++;
  }
  print "\n";


}
$sth->finish();

$dbh->disconnect();
exit;

##################################################
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
##################################################
sub help {
    print "Default Options: \n";
    print "  If OS_TENANT_NAME is set it will display instances for that project\n";
    print "  Otherwise instances for all projects will be displayed.\n";
    print "  Default display fields are all fields\n\n";

    print "Optional:  \n";
    print "          --tenant <tenant>\n";
    print "          --all-tenants\n";
    print "          --fields <comma separated list of fields> \n";
    print "Display Fields: \n";
    for my $field (@Fields) {
        print "      $field \n";
    }

}
