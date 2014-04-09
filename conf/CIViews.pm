package CIViews;

my $bin_dir   = "$FindBin::Bin/../bin";
my $conf_file = "$FindBin::Bin/../conf/cloud.cfg";

my $conf_ref = get_conf();
my %Conf = %$conf_ref;

my $default_view = "instances";

# To add a new View the following sections need to be updated
# 1. View Names
# 2. View Colums 
# 3. SQL Statements or External Sources


#################################################################
#################################################################

sub View { 
   my $requested_view = shift;
   my %View = ();

   ######################################################################################
   ######################################################################################
   # View Names Section
   ######################################################################################
   
   my %AllViews = (); 
   $AllViews{instances}      = { viewname => "Instances", source => 'sql', order => 1 };
   $AllViews{computes}       = { viewname => "Computes", source => 'sql', order => 2 }; 
   $AllViews{services}       = { viewname => "Services", source => 'sql', order => 3 }; 
   $AllViews{tenants}        = { viewname => "Tenants", source => 'sql', order => 4 };
   $AllViews{capacity}       = { viewname => "Capacity", source => 'external', order => 5 };
   $AllViews{metrics}        = { viewname => "Metrics", source => 'external',  order => 6 };

   ######################################################################################
   # Define subview names here 
   $AllViews{subview_instance_details} = { viewname => "Instance Details", source => 'sql', orientation => 'vertical' };
   $AllViews{subview_errors}           = { viewname => "Instance Errors", source => 'sql' };
   $AllViews{subview_caphistory}       = { viewname => "Capacity History", source => 'sql' };

 
   ######################################################################################
   ######################################################################################
   # View columns Section
   ######################################################################################

   my %Instances = ();
   $Instances{display_name}  = { colname => 'Instance', align => 'left', sort_type => 'alpha', order => 1 };
   $Instances{uuid}          = { colname => 'UUID', align => 'left', link => 'subview_instance_details', sort_type => 'alpha', order => 2 };
   $Instances{host}          = { colname => 'Host',  align => 'left', link => 'computes', sort_type => 'alpha', order => 3 };
   $Instances{name}          = { colname => 'Tenant', align => 'left', link => 'tenants', sort_type => 'alpha', order => 4 };
   $Instances{memory_mb}     = { colname => 'Memory', align => 'right', sort_type => 'num', order => 5 };
   $Instances{vcpus}         = { colname => 'CPUs', align => 'right', sort_type => 'num', order => 6 };
   $Instances{root_gb}       = { colname => 'Disk', align => 'right', sort_type => 'num', order => 7 };
   $Instances{floating_ip}   = { colname => 'Floating IP', align => 'left', sort_type => 'alpha', order => 8 };
   $Instances{fixed_ip}      = { colname => 'Fixed IP', align => 'left', sort_type => 'alpha', order => 9 };
   $Instances{image_name}    = { colname => 'Image Name', align => 'left', sort_type => 'alpha', order => 10 };
   $Instances{vm_state}      = { colname => 'Status', align => 'left', link => 'subview_errors', link_hook => 2, sort_type => 'alpha', order => 11 };
   $Instances{task_state}    = { colname => 'Task', align => 'left', sort_type => 'alpha', order => 12 };
   $Instances{created_at}    = { colname => 'Created at', align => 'right', sort_type => 'alpha', default_sort => 'des', order => 13 };

   my %Tenants = ();
   $Tenants{name}            = { colname => 'Tenant', align => 'left', sort_type => 'alpha', default_sort => 'asc', order => 1 };
   $Tenants{id}              = { colname => 'VMs Used', align => 'right', sort_type => 'num', order => 2 };
   $Tenants{instances_limit} = { colname => 'VMs Limit', align => 'right', sort_type => 'num', order => 3 };
   $Tenants{memory_mb}       = { colname => 'RAM Used (MB)', align => 'right', sort_type => 'num', order => 4 };
   $Tenants{ram_limit}       = { colname => 'RAM Limit (MB)', align => 'right', sort_type => 'num', order => 5 };
   $Tenants{vcpus}           = { colname => 'Cores Used', align => 'right', sort_type => 'num', order => 6 };
   $Tenants{cores_limit}     = { colname => 'Cores Limit', align => 'right', sort_type => 'num', order => 7 };
   $Tenants{root_gb}         = { colname => 'Disk Used (GB)', align => 'right', sort_type => 'num', order => 8 };
   $Tenants{ram_hours}       = { colname => 'RAM MB-Hours', align => 'right', sort_type => 'num', order => 9 };
   $Tenants{cpu_hours}       = { colname => 'CPU Hours', align => 'right', sort_type => 'num', order => 10 };
   $Tenants{disk_hours}      = { colname => 'Disk GB-Hours', align => 'right', sort_type => 'num', order => 11 };
   
   my %Computes = ();
   $Computes{hypervisor_hostname}  = { colname => 'Hypervisor', align => 'left', sort_type => 'alpha', default_sort => 'asc', order => 1 };
   $Computes{status}		   = { colname => 'Status', align => 'left', sort_type => 'alpha', order => 2 }; 
   $Computes{ha}                   = { colname => 'Aggregate', align => 'left', sort_type => 'text', order => 3 };
   $Computes{vcpus}                = { colname => 'CPUs', align => 'right', sort_type => 'num', order => 4 };
   $Computes{vcpus_used}           = { colname => 'CPUs Used', align => 'right', sort_type => 'num', order => 5 };
   $Computes{memory_mb}            = { colname => 'RAM (MB)', align => 'right', sort_type => 'num', order => 6 };
   $Computes{memory_mb_used}       = { colname => 'RAM Used (MB)', align => 'right', sort_type => 'num', order => 7 };
   $Computes{local_gb}             = { colname => 'Disk (GB)', align => 'right', sort_type => 'num', order => 8 };
   $Computes{local_gb_used}        = { colname => 'Disk Used (GB)', align => 'right', sort_type => 'num', order => 9 };
   $Computes{free_disk_gb}         = { colname => 'Disk Avail (GB)', align => 'right', sort_type => 'num', order => 10 };
   $Computes{disk_available_least} = { colname => 'Disk Avail Least (GB)', align => 'right', sort_type => 'num', order => 11 };
   $Computes{running_vms}          = { colname => 'Running VMs', align => 'right', sort_type => 'num', order => 12 };

   my %Services = ();
   $Services{service}    = { colname => 'Service', align => 'left', sort_type => 'alpha', order => 1 };
   $Services{host}       = { colname => 'Host', align => 'left', sort_type => 'alpha', order => 2 };
   $Services{status}     = { colname => 'Status', align => 'left', sort_type => 'alpha', order => 3 };
   $Services{state}      = { colname => 'State', align => 'left', sort_type => 'alpha', default_sort => 'asc', order => 4 };
   $Services{updated_at} = { colname => 'Updated At', align => 'right', sort_type => 'alpha', order => 5 };

   my %Capacity = ();
   $Capacity{ha}           = { colname => 'Aggregate', align => 'left', sort_type => 'apha', order => 1 };   
   $Capacity{vms}          = { colname => 'VMs', align => 'right', sort_type => 'num', default_sort => 'des', order => 2 };
   $Capacity{hvs}          = { colname => 'Hypervisors', align => 'right', sort_type => 'num',  order => 3 };
   $Capacity{cpus}         = { colname => 'CPUs Total', align => 'right', sort_type => 'num',  order => 4 };
   $Capacity{cpus_used}    = { colname => 'CPUs Used', align => 'right', sort_type => 'num',  order => 5 };
   $Capacity{cpus_avail}   = { colname => 'CPUs Avail', align => 'right', sort_type => 'num',  order => 6 };
   $Capacity{memory}       = { colname => 'RAM Total(GB)', align => 'right', sort_type => 'num',  order => 7 };
   $Capacity{memory_used}  = { colname => 'RAM Used (GB)', align => 'right', sort_type => 'num',  order => 8 };
   $Capacity{memory_avail} = { colname => 'RAM Avail (GB)', align => 'right', sort_type => 'num',  order => 9 };
   $Capacity{disk}         = { colname => 'Disk Total (GB)', align => 'right', sort_type => 'num',  order => 10 };
   $Capacity{disk_used}    = { colname => 'Disk Used (GB)', align => 'right', sort_type => 'num',  order => 11 };
   $Capacity{disk_avail}   = { colname => 'Disk Avail (GB)', align => 'right', sort_type => 'num',  order => 12 };
   $Capacity{disk_avail_least} = { colname => 'Disk Avail Least (GB)', align => 'right', sort_type => 'num',  order => 13 };
   $Capacity{history}          = { colname => 'History', align => 'right', sort_type => 'alpha', link => 'subview_caphistory', link_hook => 1, order => 14 };

   my %CapHistory = ();
   $CapHistory{date}         = { colname => 'Date', align => 'right', sort_type => 'apha', default_sort => 'des', order => 1 };
   $CapHistory{vms}          = { colname => 'VMs', align => 'right', sort_type => 'num', order => 2 };
   $CapHistory{hvs}          = { colname => 'Hypervisors', align => 'right', sort_type => 'num',  order => 3 };
   $CapHistory{cpus}         = { colname => 'CPUs Total', align => 'right', sort_type => 'num',  order => 4 };
   $CapHistory{cpus_used}    = { colname => 'CPUs Used', align => 'right', sort_type => 'num',  order => 5 };
   $CapHistory{cpus_avail}   = { colname => 'CPUs Avail', align => 'right', sort_type => 'num',  order => 6 };
   $CapHistory{memory}       = { colname => 'RAM Total(GB)', align => 'right', sort_type => 'num',  order => 7 };
   $CapHistory{memory_used}  = { colname => 'RAM Used (GB)', align => 'right', sort_type => 'num',  order => 8 };
   $CapHistory{memory_avail} = { colname => 'RAM Avail (GB)', align => 'right', sort_type => 'num',  order => 9 };
   $CapHistory{disk}         = { colname => 'Disk Total (GB)', align => 'right', sort_type => 'num',  order => 10 };
   $CapHistory{disk_used}    = { colname => 'Disk Used (GB)', align => 'right', sort_type => 'num',  order => 11 };
   $CapHistory{disk_avail}   = { colname => 'Disk Avail (GB)', align => 'right', sort_type => 'num',  order => 12 };
   $CapHistory{disk_avail_least} = { colname => 'Disk Avail Least (GB)', align => 'right', sort_type => 'num',  order => 13 };

   my %Metrics = ();
   $Metrics{name}         = { colname => 'Name', align => 'left', link => 'graph', order => 1 };
   $Metrics{value}        = { colname => 'Current Data', align => 'right', sort_type => 'apha', order => 2 };

   my %Reports = ();
   $Reports{date}                   = { colname => 'Date', align => 'right', sort_type => 'apha', default_sort => 'des', order => 1 };
   $Reports{total_vms}              = { colname => 'Total VMs', align => 'right', sort_type => 'num', order => 2 };
   $Reports{hv_used}                = { colname => 'HVs Used', align => 'right', sort_type => 'num', order => 3 };
   $Reports{hv_total}               = { colname => 'Total HVs ', align => 'right', sort_type => 'num', order => 4 };
   $Reports{users}                  = { colname => 'Users', align => 'right', sort_type => 'num', order => 5 };
   $Reports{cpu_total}              = { colname => 'Total CPU', align => 'right', sort_type => 'num', order => 6 };
   $Reports{memory_total}           = { colname => 'Total RAM (GB)', align => 'right', sort_type => 'num', order => 7 };
   $Reports{disk_total}             = { colname => 'Total Disk (GB)', align => 'right', sort_type => 'num', order => 8 };
   $Reports{cpu_used}               = { colname => 'CPUs Used', align => 'right', sort_type => 'num', order => 9 };
   $Reports{memory_used}            = { colname => 'RAM Used (GB)', align => 'right', sort_type => 'num', order => 10 };
   $Reports{disk_used}              = { colname => 'Disk Used (GB)', align => 'right', sort_type => 'num', order => 11 };
   $Reports{cpu_available}          = { colname => 'CPU Avail', align => 'right', sort_type => 'num', order => 12 };
   $Reports{memory_available}       = { colname => 'RAM Avail (GB)', align => 'right', sort_type => 'num', order => 13 };
   $Reports{disk_available}         = { colname => 'Disk Avail (GB)', align => 'right', sort_type => 'num', order => 14 };
   $Reports{vms_created}            = { colname => 'VMs Created', align => 'right', sort_type => 'num', order => 15 };
   $Reports{vms_failed}             = { colname => 'VMs Failed', align => 'right', sort_type => 'num', order => 16 };
   $Reports{vms_active}             = { colname => 'VMs Active', align => 'right', sort_type => 'num', order => 17 };

   my %InstanceDetails = ();
   $InstanceDetails{uuid}           = { colname => 'UUID', order => 1 };
   $InstanceDetails{hostname}       = { colname => 'Hostname', order => 2 };
   $InstanceDetails{display_name}   = { colname => 'Display Name', order => 3 };
   $InstanceDetails{cpu}            = { colname => 'CPUs', order => 4 };
   $InstanceDetails{memory_mb}      = { colname => 'Memory (MB)', order => 5 };
   $InstanceDetails{disk}           = { colname => 'Disk (GB)', order => 6 };
   $InstanceDetails{user_id}        = { colname => 'User ID', order => 7 };
   $InstanceDetails{user_name}      = { colname => 'User Name', order => 8 };
   $InstanceDetails{project_id}     = { colname => 'Project ID', order => 9 };
   $InstanceDetails{project_name}   = { colname => 'Project Name', order => 10 };
   $InstanceDetails{ip_floating}    = { colname => 'IP floating', order => 11 };
   $InstanceDetails{ip_fixed}       = { colname => 'IP fixed', order => 12 };
   $InstanceDetails{image}          = { colname => 'Image', order => 13 };
   $InstanceDetails{flavor}         = { colname => 'Flavor', order => 14 };
   $InstanceDetails{hypervisor}     = { colname => 'Hypervisor', order => 15 };
   $InstanceDetails{state}          = { colname => 'State', order => 16 };
   $InstanceDetails{task}           = { colname => 'Current Task', order => 17 };
   $InstanceDetails{created}        = { colname => 'Created at', order => 18 };
   $InstanceDetails{updated}        = { colname => 'Updated at', order => 19 };
  

 
   ########################################
   my %Errors = ();
   $Errors{created}    = { colname => 'Created', align => 'right', sort_type => 'alpha', default_sort => 'asc', order => 1 };
   #$Errors{code}       = { colname => 'Code', align => 'right', sort_type => 'num', order => 2 };
   $Errors{message}    = { colname => 'Message', align => 'left', sort_type => 'alpha', order => 2 };
   $Errors{details}    = { colname => 'Details', align => 'left', sort_type => 'alpha', order => 3 };
   $Errors{host}       = { colname => 'Host', align => 'right', sort_type => 'alpha', order => 4 };


   #######################################
   my %GraphTimeRange = ();
   $GraphTimeRange{days_1}   = { name => '1 Day',    days => '1days', order => '1' };
   $GraphTimeRange{days_7}   = { name => '7 Days',   days => '7days', default => 'true', order => '2' };
   $GraphTimeRange{days_30}  = { name => '1 Month',  days => '30days', order => '3' };
   $GraphTimeRange{days_90}  = { name => '3 Months', days => '90days', order => '4' };
   $GraphTimeRange{days_180} = { name => '6 Months', days => '180days', order => '5' };
   $GraphTimeRange{days_365} = { name => '1 Year',   days => '365days', order => '5' };


   #######################################
   if ( $requested_view eq "all_views" ) {
      %View = %AllViews;
   }
   elsif( $requested_view eq "tenants" ) {
      %View = %Tenants; 
   } 
   elsif ( $requested_view eq "computes" ) {
      %View = %Computes;
   }
   elsif ( $requested_view eq "services" ) {
      %View = %Services;
   }
   elsif ( $requested_view eq "instances" or $requested_view eq "" ) {
      %View = %Instances;
   }
   elsif ( $requested_view eq "capacity" ) {
      %View = %Capacity;
   }
   elsif ( $requested_view eq "metrics" ) {
      %View = %Metrics;
   }
   elsif ( $requested_view eq "subview_instance_details" ) {
      %View = %InstanceDetails;
   }
   elsif ( $requested_view eq "subview_errors" ) {
      %View = %Errors;
   }
   elsif ( $requested_view eq "subview_caphistory" ) {
      %View = %CapHistory;
   }
   elsif ( $requested_view eq "graph_time_range" ) {
      %View = %GraphTimeRange;
   }
   
   return \%View;

}

##########################################################################
##########################################################################
# SQL Statements Section
##########################################################################

sub sql_stmt {

   my $requested_view = shift;
   my $requested_item  = shift;
   my $where_item;
   my %SQL = ();
   if ( $requested_view eq "" ) {
      $requested_view = $default_view;
   }

   if ( $requested_item ne "" ) {
      if ($requested_view eq "tenants" ) {
         $where_item = qq[and t.name = "$requested_item"];
      } 
      elsif ($requested_view eq "computes" ) {
         $where_item = qq[and hypervisor_hostname like "%${requested_item}%"];
      }
      elsif ($requested_view eq "subview_instance_details" ) {
         $where_item = qq[i.uuid = "$requested_item"];
      }
      elsif ($requested_view eq "subview_errors" ) { 
         $where_item = qq[instance_uuid = "$requested_item"];
      }
      elsif ($requested_view eq "subview_caphistory" ) {
         $where_item = qq[aggregate = "$requested_item"];
      }

   }
   else {
      $where_item = "";
   }

   ##############################################################################
   #  Define SQL statements here
   ##############################################################################

   $SQL{instances} = "select i.hostname, i.uuid, i.host, t.name, i.memory_mb, i.vcpus, i.root_gb, flip.floating_ip_address, ipall.ip_address, g.name, i.vm_state, i.task_state, i.created_at FROM $Conf{NOVA_DB}.instances i LEFT JOIN $Conf{QUANTUM_DB}.ports p on p.device_id = i.uuid LEFT JOIN $Conf{QUANTUM_DB}.floatingips flip on flip.fixed_port_id = p.id LEFT JOIN $Conf{QUANTUM_DB}.ipallocations ipall on ipall.port_id = p.id LEFT JOIN $Conf{KEYSTONE_DB}.project t on i.project_id = t.id LEFT JOIN $Conf{GLANCE_DB}.images g on g.id = i.image_ref where i.deleted = 0";

   $SQL{tenants} = qq[select t.name, count(i.id), IFNULL((select max(case when nq.resource = 'instances' then nq.hard_limit end ) Instances from $Conf{NOVA_DB}.quotas nq where nq.deleted = 0 and nq.project_id = t.id),'$Conf{instances_default_limit}'), sum(i.memory_mb), IFNULL((select  max(case when nq.resource = 'ram' then nq.hard_limit end ) RAM from $Conf{NOVA_DB}.quotas nq where nq.deleted = 0 and nq.project_id = t.id),'$Conf{ram_default_limit}'), sum(i.vcpus), IFNULL((select max(case when nq.resource = 'cores' then nq.hard_limit end ) CORES from $Conf{NOVA_DB}.quotas nq where nq.deleted = 0 and nq.project_id = t.id),'$Conf{cores_default_limit}'), sum(i.root_gb), tu.ram_hours,tu.cpu_hours,tu.disk_hours from $Conf{KEYSTONE_DB}.project t left JOIN $Conf{NOVA_DB}.instances i on  t.id = i.project_id left JOIN $Conf{CLOUDINFO_DB}.tenant_usage tu on tu.tenant_id = t.id where i.deleted =0 $where_item group by t.name];

   $SQL{computes} = qq[select SUBSTRING_INDEX(cn.hypervisor_hostname, '.', 1), IF((s.disabled = 0 and s.`binary` = 'nova-compute'), 'enabled', 'disabled'), IFNULL((select a.name from $Conf{NOVA_DB}.aggregate_hosts ah LEFT JOIN $Conf{NOVA_DB}.aggregates a ON a.id=ah.aggregate_id where SUBSTRING_INDEX(host, '.', 1) = SUBSTRING_INDEX(hypervisor_hostname, '.', 1) and a.name not like '%fz_%' and ah.deleted=0 and a.deleted=0), 'General_Purpose'), cn.vcpus,cn.vcpus_used,cn.memory_mb,cn.memory_mb_used,cn.local_gb,cn.local_gb_used,cn.free_disk_gb,cn.disk_available_least,cn.running_vms from $Conf{NOVA_DB}.compute_nodes cn LEFT JOIN $Conf{NOVA_DB}.services s ON cn.service_id=s.id where cn.deleted = 0 $where_item];

   $SQL{services} = qq[select `binary`, host, IF(disabled = 0, 'enabled', 'disabled'), IF(updated_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE), 'Failed', 'OK'), updated_at from services where deleted = 0];  

   ####################################  
   #  Subviews
   ####################################
   $SQL{subview_instance_details} = "select i.uuid, i.hostname, i.display_name, i.vcpus, i.memory_mb, i.root_gb+i.ephemeral_gb, i.user_id, i.user_id, i.project_id, t.name, flip.floating_ip_address, ipall.ip_address, g.name, itypes.name, i.host, i.vm_state, i.task_state, i.created_at, i.updated_at FROM $Conf{NOVA_DB}.instances i LEFT JOIN $Conf{QUANTUM_DB}.ports p on p.device_id = i.uuid LEFT JOIN $Conf{QUANTUM_DB}.floatingips flip on flip.fixed_port_id = p.id LEFT JOIN $Conf{QUANTUM_DB}.ipallocations ipall on ipall.port_id = p.id LEFT JOIN $Conf{KEYSTONE_DB}.project t on i.project_id = t.id LEFT JOIN $Conf{GLANCE_DB}.images g on g.id = i.image_ref LEFT JOIN $Conf{NOVA_DB}.instance_types itypes on i.instance_type_id = itypes.id where $where_item";

   $SQL{subview_errors} = "select created_at,message,details,host from instance_faults where $where_item"; 

   $SQL{subview_caphistory} = qq[select date,vms,hvs,cpus,cpus_used,cpus_avail,memory,memory_used,memory_avail,disk,disk_used,disk_avail,disk_avail_least from $Conf{CLOUDINFO_DB}.capacity_history where $where_item]; 

   return $SQL{$requested_view};
}

########################################################################
########################################################################
# External Sources Section 
########################################################################

sub external_source {
    my $requested_view = shift;
    my @Rows_AoA = ();
    my $external_script;
    my $text_link;
    
    if ($requested_view eq "metrics" ) {
       $external_script = "${bin_dir}/cloudstats.pl";
    }
    elsif ($requested_view eq "capacity" ) {
       $external_script = "${bin_dir}/capacity_and_stats.pl --report capacity --csv";
       $text_link = "view";
    }

    my @Output = `$external_script`;
    foreach my $line (@Output) {
       chomp($line);
       next if ($line eq "" );
       my @row = split(/\^\^/,$line);

       if ($text_link) {
           push @row, "$text_link";
       }
       push @Rows_AoA, [ @row ];
    }

    return \@Rows_AoA;
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
