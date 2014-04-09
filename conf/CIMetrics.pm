package CIMetrics;

my $conf_file = "$FindBin::Bin/../conf/cloud.cfg";
my $conf_ref = get_conf();
my %Conf = %$conf_ref;


my $date = `date +%Y-%m-%d`;
chomp($date);
### TODO  not hardcoded hour
my $utc_start_hour = "$date 07:00:00";


#################################################################
#################################################################

sub Metrics {
   my %AllMetrics = ();

   $AllMetrics{vms_total}             = { name => "VMs Total", source => 'sql', groups => 'hourly', order => 1 };
   $AllMetrics{vms_active_today}      = { name => "VMs Daily Active", source => 'sql', groups => 'daily', order => 2 };
   $AllMetrics{vms_created_today}     = { name => "VMs Daily Created", source => 'sql', groups => 'daily', order => 3 };
   $AllMetrics{vms_failed_today}      = { name => "VMs Daily Failed", source => 'sql', groups => 'daily', order => 4 };

   $AllMetrics{vms_cm_deleted_total}  = { name => "VMs CloudMinion Deleted Total", source => 'external', groups => 'hourly', order => 5 };
   $AllMetrics{vms_cm_deleted_daily}  = { name => "VMs CloudMinion Deleted Daily", source => 'external', groups => 'daily', order => 6 };

   $AllMetrics{hypervisors_total}     = { name => "Hypervisors Total", source => 'sql', groups => 'hourly', order => 7 };

   $AllMetrics{services_compute_disabled}  = { name => "Services Compute Disabled", source => 'sql', groups => 'hourly', order => 8 };   
   $AllMetrics{services_compute_failed}   = { name => "Services Compute Failed", source => 'sql', groups => 'hourly', order => 9 };

   $AllMetrics{users_total}             = { name => "Users Total", source => 'sql', groups => 'hourly', order => 12 };
   $AllMetrics{users_active}            = { name => "Users Active", source => 'sql', groups => 'hourly', order => 13 }; 

   $AllMetrics{tenants_total}             = { name => "Tenants Total", source => 'sql', groups => 'hourly', order => 14 };
   $AllMetrics{tenants_active}            = { name => "Tenants Active", source => 'sql', groups => 'hourly', order => 15 };

   ######################################
   #Capacity available IPs subnets 
 
   if ( defined $Conf{capacity_subnets} ) {
       my @Subnets = split(/,/,$Conf{capacity_subnets});
       # Get last order number
       my $last_order_number = 0;
       for my $key ( keys %AllMetrics ) {
           $last_order_number = $AllMetrics{$key}{order} if $AllMetrics{$key}{order} > $last_order_number;
       }
       foreach my $subnet (@Subnets) {
           $last_order_number++;
           my $key = "capacity_available_ips_${subnet}";
           $AllMetrics{$key} = { name => "Capacity Available IPs $subnet", argument => $subnet, source => 'external', groups => 'hourly', order => $last_order_number };
       }
   }

   ######################################
   #Capacity available instances flavor

   if ( defined $Conf{capacity_flavors} ) {
       my @Flavors = split(/,/,$Conf{capacity_flavors});
       # Get last order number
       my $last_order_number = 0;
       for my $key ( keys %AllMetrics ) {
           $last_order_number = $AllMetrics{$key}{order} if $AllMetrics{$key}{order} > $last_order_number;
       }
       foreach my $flavor (@Flavors) {
           $last_order_number++;
           my $key = "capacity_available_instances_${flavor}";
           $AllMetrics{$key} = { name => "Capacity Available Instances $flavor", argument => $flavor, source => 'external', groups => 'hourly', order => $last_order_number };
       }
   }

   return \%AllMetrics;

}

#################################################################
sub SQL_Statements {

   my %SQL = ();
   
   ##############################################################################
   #  Define SQL statements here
   ##############################################################################

   $SQL{vms_total} = qq[select count(uuid) from $Conf{NOVA_DB}.instances where deleted = 0]; 
   $SQL{vms_active_today} = qq[select count(uuid) from $Conf{NOVA_DB}.instances where created_at>="$utc_start_hour" and vm_state = 'active'];
   $SQL{vms_created_today} = qq[select count(uuid) from $Conf{NOVA_DB}.instances where created_at>='$utc_start_hour']; 
   $SQL{vms_failed_today} = qq[select count(distinct(instance_uuid)) from $Conf{NOVA_DB}.instance_faults where created_at>='$utc_start_hour']; 

   $SQL{hypervisors_total} = qq[select count(hypervisor_hostname) from $Conf{NOVA_DB}.compute_nodes where deleted = 0];

   $SQL{services_compute_disabled} = qq[select count(host) from $Conf{NOVA_DB}.services where deleted = 0 and `binary` = 'nova-compute' and disabled = 1];
   $SQL{services_compute_failed} = qq[select count(host) from $Conf{NOVA_DB}.services where updated_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE) and `binary` = 'nova-compute' and deleted = 0];

   $SQL{users_total} = qq[select count(name) from $Conf{KEYSTONE_DB}.project where description like '%autotenancy%' and name not in (select name from $Conf{KEYSTONE_DB}.user)];
   $SQL{users_active} = qq[select count(distinct user_id) from $Conf{NOVA_DB}.instances where deleted = 0];

   $SQL{tenants_total} = qq[select count(id) from $Conf{KEYSTONE_DB}.project where enabled = 1];
   $SQL{tenants_active} = qq[select count(distinct project_id) from $Conf{NOVA_DB}.instances where deleted = 0];
   #$SQL{ips_floating_total} = qq[];
   
   return \%SQL;

}
#################################################################
sub External_Source {
    my $metric = shift;
    my $script_argument = shift;

    my $external_script;
    if ( $metric eq "vms_cm_deleted_total" ) {
        $external_script = "$FindBin::Bin/cm_stats.pl --total";
    }
    if ( $metric eq "vms_cm_deleted_daily" ) {
        $external_script = "$FindBin::Bin/cm_stats.pl --daily";
    }
    elsif ( $metric =~ m/capacity_available_ips_/ ) {
        $external_script = "$FindBin::Bin/available_ips_quantum.pl --subnet $script_argument";
      
    }
    elsif ( $metric =~ m/capacity_available_instances_/ ) {
       $external_script = "$FindBin::Bin/available_instances.pl --flavor $script_argument";
    }

    my $output = `$external_script`;
    chomp ($output);

    return ($output);    

}

################################################################
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

1;
