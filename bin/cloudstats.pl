#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../conf";
use CIMetrics;

my $conf_file = "$FindBin::Bin/../conf/cloud.cfg";
my $conf_ref = get_conf();
my %Conf = %$conf_ref;

my $carbon_cli = "$FindBin::Bin/carbon-cli.py";

my ($metrics, $group, $carbon, $debug, $noop);
GetOptions( 'metrics=s'   => \$metrics,
            'group=s'     => \$group,
            'carbon'      => \$carbon,
            'debug'       => \$debug,
            'noop'        => \$noop,
);

my $Hash_ref = CIMetrics::Metrics("all_metrics");
my %AllMetrics = %$Hash_ref;

my @Requested_Metrics = ();
if ( defined $metrics ) {
   $metrics =~ s/\s+//g;
   @Requested_Metrics = split(/,/,$metrics);
}
elsif ( defined $group ) {
   for my $key ( keys %AllMetrics ) {
       if ( defined $AllMetrics{$key}{groups} ) {
           my @Groups = split(/,/,$AllMetrics{$key}{groups});
           foreach my $defined_group (@Groups) {
               $defined_group =~ s/\s+//g;
               if ( $group eq $defined_group ) {
                   push @Requested_Metrics, $key;
               }
           }
       }
   }   
}

##################################################

my $SQL_Statements_ref = CIMetrics::SQL_Statements();
my %SQL_Statements = %$SQL_Statements_ref;


my $dbh = DBI->connect("DBI:mysql:database=$Conf{NOVA_DB};host=$Conf{DB_HOST};port=$Conf{DB_PORT}", "$Conf{READONLY_USER}", "$Conf{READONLY_PASSWORD}",
               {'RaiseError' => 1 });

for my $key (sort { $AllMetrics{$a}{order} <=> $AllMetrics{$b}{order} } keys %AllMetrics) {

    if ( defined @Requested_Metrics ) {
        my $found = 0;
        foreach my $metric (@Requested_Metrics) {
            if ("$metric" eq "$key") {
               $found = 1;
               last;
            }
        }
        if ( $found == 0 ) {
             next;
        } 
    }

    my $MetricsName = $AllMetrics{$key}{name};
    my $source = $AllMetrics{$key}{source};
    my $sql;
    my $MetricsValueResult;

    if ( $source eq "sql" ) {
       $sql = $SQL_Statements{$key};
       #print "$MetricsName = $sql\n";
     
       my $sth = $dbh->prepare($sql);
       $sth->execute();
       $MetricsValueResult = $sth->fetchrow_array();
       $sth->finish();
    }
    elsif ( $source eq "external" ) {
       my $script_argument;
       if ( defined $AllMetrics{$key}{argument} ) { 
           $script_argument = $AllMetrics{$key}{argument};
       }
       $MetricsValueResult = CIMetrics::External_Source($key, $script_argument);
    }

    my @MetricsValues = split(/\n/,$MetricsValueResult);


    foreach my $MV (@MetricsValues ) {
        my $MetricsValue;
        my $MetricsAppend;
        if ( $MV =~ m/(.*)=(.*)/ ) {
            $MetricsAppend = " $1";
            $MetricsValue = $2;   
        }
        else {
            $MetricsValue = $MV;
        }
        my $GraphiteName = "$MetricsName${MetricsAppend}";;
        #print "${MetricsName}${MetricsAppend}^^$MetricsValue\n";
        print "$GraphiteName^^$MetricsValue\n";
 
        # Insert into graphite
        if ( defined $MetricsValue and defined $carbon) {
            $GraphiteName =~ s/\s+/./g;
            $GraphiteName = "$Conf{DATACENTER}.${GraphiteName}";

            my $carbon_cli_cmd = "$carbon_cli $GraphiteName $MetricsValue"; 
            print "$carbon_cli_cmd\n" if defined $debug;
            if ( ! defined $noop ) {
                system ("$carbon_cli_cmd");
            }
        }
    }
}
$dbh->disconnect();

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
