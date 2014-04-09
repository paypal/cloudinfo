#!/usr/bin/perl

use strict;
use File::Basename;
use FindBin;
use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use DBI;
use lib "$FindBin::Bin/../conf";
use CIViews;

my $conf_file = "$FindBin::Bin/../conf/cloud.cfg";
my $conf_ref = get_conf();
my %Conf = %$conf_ref;

my $cgi_script = basename($0);
my $main_title = "$Conf{DATACENTER} Cloud Info";

my %bg_color = (
       0 => '#FFFFFF',
       1 => '#EFF5FB'
);

my %Entities = (
    all  => 'All',
); 

my $q = new CGI;
my $params     = $q->Vars;
my $tab        = $params->{'tab'};
my $sortby     = $params->{'sortby'};
my $sortorder  = $params->{'sortorder'};
my $search_str = trim($params->{'search_str'});
my $filter     = $params->{'filter'};
my $item       = $params->{'item'};
my $iframe     = $params->{'iframe'};

my $param_list;
my $tab_param;
my $sort_param;
my $search_param;
my $filter_param;
my $passon_params;

if ( $tab ne "" ) {
   $tab_param = "tab=$tab";
}
if ( $sortby ne "" ) {
   $sort_param = "&sortby=$sortby";
}
if ( $search_str ne "" ) {
   $search_param = "&search_str=$search_str";
}
if ( $filter ne "" ) {
   $filter_param = "&filter=$filter";
}

my $tab_passon    = "${search_param}";
my $sort_passon   = "${tab_param}${search_param}${filter_param}";
my $filter_passon = "${tab_param}${sort_param}${search_param}";
my $search_passon = "${tab_param}${filter_param}${sort_param}";

#######################################################
# Filter strings
my %Filters = (
   all => 'All',
);

########################################################
my %CurrentTab;
my $tab_title;

my $Hash_ref = CIViews::View("all_views");
my %AllViews = %$Hash_ref;

my $GraphTimeRange_ref = CIViews::View("graph_time_range");
my %GraphTimeRange = %$GraphTimeRange_ref;

my %ColumnNames = ();

   #TODO get tab (key) from value order = 1   Needed for empty view
   if ( $tab eq "" ) {
      $tab = "instances";
   }

   my $Hash_ref = CIViews::View("$tab");
   %ColumnNames = %$Hash_ref;
   %CurrentTab = ();
   $tab_title = $AllViews{$tab}{viewname};
   @CurrentTab{keys %ColumnNames} = values %ColumnNames;


#####################################################
# HTML
my $css_code=<<END;
a.title:link {color: #CCCCCC;}
a.title:hover {color: #FFFFFF;}
a.title{font-family: Arial,Verdana; text-decoration: none; color: #CCCCCC;}

a.top:link {color: #FE9A2E;}
a.topcage:link {color: #FFFFCC;}
a.top:visited {color: #FE9A2E;}
a.topcage:visited {color: #FFFFFF;}
a.top:active {color: #FE9A2E;}
a.top:hover {color: #DF0101;}
a.topcage:hover {color: #DF0101;}
a.top{font-family: Arial,Verdana; text-decoration: none; color: #FE9A2E;}

a.main:link {color: #000000;}
a.main:visited {color: #000000;}
a.main:active {color: #000000;}
a.main:hover {color: #DF0101;}
a.main{font-family: Arial,Verdana; text-decoration: none; color: #000000;}

a.hostname:link {color: #8A4117;}
a.hostname:visited {color: #8A4117;}
a.hostname:active {color: #8A4117;}
a.hostname:hover {color: #DF0101;}
a.hostname{font-family: Arial,Verdana; text-decoration: none; color: #8A4117; font-size: small;}
END
####################################
my $js_code=<<END_JS;

END_JS
####################################

print header;
print start_html(-title =>"$main_title",
                 -style => {-code => $css_code},
                 -script=>{-type=>'JAVASCRIPT', -code=>$js_code}
                 );
my $dbh;
if ( defined $iframe ) {
    my $graph_target = $iframe;
    print qq[<font face='Arial' size='2' color="#FFFFFF"> &nbsp; Time Period: &nbsp;</font>];
    foreach my $key (sort { $GraphTimeRange{$a}{order} <=> $GraphTimeRange{$b}{order} }keys %GraphTimeRange ) {
        my $name = $GraphTimeRange{$key}{name};
        my $days = $GraphTimeRange{$key}{days};
        my $time_range = "from=-$days&until=$Conf{graph_until}";
        my $graph_link = qq[$Conf{graphite_server}?width=$Conf{graph_width}&height=$Conf{graph_height}&lineMode=connected&target=${graph_target}&title=${graph_target}+Last+$days&${time_range}];

        print qq[<a href="$graph_link" target='GraphFrame' class='top'><font size='2'>$name</font></a> &nbsp;&nbsp;];
    }
}
else {
   $dbh = DBI->connect("DBI:mysql:database=$Conf{NOVA_DB};host=$Conf{DB_HOST};port=$Conf{DB_PORT}", "$Conf{READONLY_USER}", "$Conf{READONLY_PASSWORD}",
       {'RaiseError' => 1 });

   DisplayMain();

   $dbh->disconnect();
}
print end_html;

##############################################################
sub DisplayMain {
# FIRST ROW
    print qq[<table width="100%" border='0' cellspacing='0' cellpadding='0'>
     <tr><td>

    <table width="100%" border='0'  bgcolor="#0C2B48">
     <tr>
       <td align='left'>
         <font size='3' color="#8A4117" face="Arial,Verdana"> &nbsp; <a href="$cgi_script" class="title">$main_title</a></font>
       </td>
       <td align='right'>
           <font size='2' color="#E6E6E6" face="Arial,Verdana"><b>$tab_title</b></font>
       </td>

       <td align='right'>
           <form action="$cgi_script?$search_passon" method="POST" name="MySearch">
              <input type="text" name="search_str" value="$search_str">&nbsp;
              <a href="javascript:document.MySearch.submit();" class="top"><font size="2">Search</font></a>&nbsp;
              <a href="$cgi_script" class="top"><font size="2">Clear</font></a> &nbsp;
               <input type="hidden" name="tab" value="$tab">
            </form>
         </td>
      </tr>
      <tr>
       <td colspan='3'> 
           <font size='2' color="#E6E6E6" face="Arial,Verdana"> &nbsp; <b>Views:</b> </font>&nbsp; ];
           # Prints all view names
           for my $key (sort { $AllViews{$a}{order} <=> $AllViews{$b}{order} } keys %AllViews) {
               next if $key =~ m/subview/;
               my $viewname = $AllViews{$key}{viewname};
               print qq[
               <b><a href="?tab=${key}${tab_passon}" class="top"><font size='2'>$viewname</font></a></b> &nbsp;
               <font size='2' color="#E6E6E6" face="Arial,Verdana">|</font> &nbsp;];
           }
           print qq[
       </td>
      </tr>   

     </table>
    ]; 

    # SORT
    my ($rows_aoa_ref, $sql_columns) = fetch_rows(\%CurrentTab);
    my @SQL_Columns = split(/,/,$sql_columns);

    my $sort_type;
    my $sorted_column;
    if ( $sortby eq "" ) {
        for my $key (keys %ColumnNames) {
            if ( $ColumnNames{$key}{default_sort} ne "" ) {
                $sortorder = $ColumnNames{$key}{default_sort};
                $sorted_column =  $ColumnNames{$key}{order} - 1;
                $sort_type = $ColumnNames{$key}{sort_type};
                last;
            }
        }
    }
    else {
        $sorted_column = ($ColumnNames{$sortby}{order} - 1 );
        $sort_type = $ColumnNames{$sortby}{sort_type};
    }
   
    my @Rows_AOA = @$rows_aoa_ref;
    
    if ( $sort_type eq "num" ) {
        if ( $sortorder eq "des" ) {
            @Rows_AOA = reverse sort { $a->[$sorted_column] <=> $b->[$sorted_column] } @Rows_AOA;
        }
        else {
            @Rows_AOA = sort { $a->[$sorted_column] <=> $b->[$sorted_column] } @Rows_AOA;
        }
    }
    elsif ( $sort_type eq "alpha" ) {
        if ( $sortorder eq "des" ) {
            @Rows_AOA = reverse sort { $a->[$sorted_column] cmp $b->[$sorted_column] } @Rows_AOA;
        }
        else {
            @Rows_AOA = sort { $a->[$sorted_column] cmp $b->[$sorted_column] } @Rows_AOA;
        }
    }

    my $searched_text = "";
    if ( $search_str ne "" ) {
       my $searched_aoa_ref = search_for($search_str, \@Rows_AOA);
       @Rows_AOA = @$searched_aoa_ref;
       $searched_text = "matching <b>$search_str</b>";
    }

# SECOND ROW 
    my $rows_number = @Rows_AOA;
    print qq[<tr><td bgcolor="#D8D8D8" height="25"><font size='2' face='Arial,Verdana'> &nbsp; Showing $rows_number items</font></td></tr>\n];

   ####################################
   # Third row
    print qq[<tr><td>
       <table width='100%'><tr><td bgcolor="#424242">
        <table bgcolor="#cccccc"><tr><td valign='top'>
         <table border='0' cellspacing='1' cellpadding='3'>\n];
   ##############################################################
   # Title Row  - ColumnNames
   print qq[<tr bgcolor='#659EC7'>\n];

   my @align_right;
   my @link_to;
   my $c_counter = 0;
   my $reverse_sort;

   if ( $AllViews{$tab}{orientation} eq "vertical" ) {
      print qq[<td><b><font size='2'>Name</font></b></td>
               <td align='center'><b><font size='2'>Value</font></b></td>];
   } 
   else {

   for my $key (sort { $ColumnNames{$a}{order} <=> $ColumnNames{$b}{order} } keys %ColumnNames) {
      my $field = $ColumnNames{$key}{colname};
      my $align = $ColumnNames{$key}{align}; 
      my $link_to = $ColumnNames{$key}{link};
      ## Align Right
      if ( $align eq "right" ) {
           push @align_right, $c_counter;
      }
      # TODO  Push links  
      if ( $link_to ne "" ) {
           push @link_to, $c_counter;
      } 
      #
      if ( $sortorder eq "asc" ) { 
          $reverse_sort = "des";
      }
      else {
          $reverse_sort = "asc";
      }
      $c_counter++;

      print qq[<td><b> <a href=$cgi_script?${sort_passon}&sortby=$key&sortorder=$reverse_sort class="main"><font size='2'>$field</font></a></b>];   
      if ( $sortby eq $key and $sortorder eq "asc" ) {
         print qq[&darr;];
      } elsif ( $sortby eq $key and $sortorder eq "des" ) { 
         print qq[&uarr;];
      }
      print qq[</td>];
   }

   } #else
   print qq[</tr>\n];


   #####################################
   #  Prints Rows  - Data Rows
   my $row_counter = 0;
   my $graph_iframe = 'false';
   my $graph_link;
   my $graph_default_link;
   my $graph_default_target;

   foreach my $row_ref (@Rows_AOA) {

       my $alt_color = $row_counter % 2;
       print qq[<tr bgcolor='$bg_color{$alt_color}'>];
       my $cell_counter = 0;
        
       foreach my $cell (@$row_ref) {
           my $seen_cell = 0;
           if ( $cell =~ m/^\d+$/ || $cell =~ m/^\d+ \(.*%\)$/) {
               $cell = comma_me($cell);
           }
         
           #############################
           # Check for cells with links
           my $ColumnKey;
           for my $key (keys %ColumnNames) {
               if ( $ColumnNames{$key}{order} == ($cell_counter + 1)) {
                  $ColumnKey = $key;
                  last;
               }
           }
           ############################
           # Links
           foreach my $link_element (@link_to) {
              if ($link_element == $cell_counter) {
                 my $link_to = $ColumnNames{$ColumnKey}{link};
            
                 if ( $ColumnNames{$ColumnKey}{link_hook} ne "" ) {
                     my $link_hook_element =  ($ColumnNames{$ColumnKey}{link_hook} - 1) ;
                     my $item = @$row_ref[$link_hook_element];

                     #TODO  make configurable
                     if ( $cell eq "error" || $cell eq "view" ) {
                        $cell = qq[<a href="$cgi_script?tab=$link_to&item=$item" class='hostname'>$cell</a>];
                     }
                     
                 }
                 else {
                     if ( $link_to eq "graph" ) {
                        $graph_iframe = 'true';
                        my $graph_target = "$Conf{DATACENTER} ${cell}";
                        $graph_target =~ s/\s+/./g;
                        my $time_range = "from=-$Conf{graph_from}&until=$Conf{graph_until}";
                        $graph_link = qq[$Conf{graphite_server}?width=$Conf{graph_width}&height=$Conf{graph_height}&lineMode=connected&target=${graph_target}&title=${graph_target}+Last+$Conf{graph_from}&${time_range}];
                        $cell = qq[<a href="$graph_link" target="GraphFrame" class="hostname" onclick="window.TimeRangeFrame.location.href='$cgi_script?iframe=${graph_target}';return true;">$cell</a>];
                        if ( $row_counter == 0 ) {
                            $graph_default_link = $graph_link;
                            $graph_default_target = $graph_target;
                        }
                     }
                     else {
                        $cell = "<a href=$cgi_script?tab=$link_to&item=$cell class='hostname'>$cell</a>";
                     }
                 }
              }
           }

           ##############################
           # Align right
           foreach my $ar_element (@align_right) {
              if ($ar_element == $cell_counter) {
                  # Align = right
                  print qq[<td align='right'> <font face='Arial' size='2'>$cell</font> </td>];
                  $seen_cell = 1;
                  last;
              }
           }

           ##############################
           # Align left
           if ($seen_cell == 0) {
               my $align = "left";
               print qq[<td align="$align"> <font face='Arial' size='2'>$cell</font> </td>];
           }
           $cell_counter++;
      }
      print qq[</tr>\n];
      $row_counter++;
   }

   print qq[</table>]; 
   print qq[      </td>];
          # Here goes the graph
          if ( $graph_iframe eq "true" ) {
              print qq[
                 <td width='50'></td>
                  <td align="right" valign='top' bgcolor="#000000">  
                  <iframe name="GraphFrame" src="$graph_default_link" frameborder="0" scrolling="auto" width="800" height="450" marginwidth="0" marginheight="0" ></iframe><br>
                  <iframe name="TimeRangeFrame" src="$cgi_script?iframe=$graph_default_target" frameborder="0" scrolling="auto" width="800" height="30" marginwidth="0" marginheight="0" ></iframe>];
          }
   print qq[
                  </td></tr></table> 
   </td></tr></table> 
   </td></tr>
 </table>
   ];
   
}

################################################################
sub fetch_rows {
    my $CurrentTab_ref = shift;
    %CurrentTab = %$CurrentTab_ref;
    my @Rows_AoA = ();
    my $sql;
    my $query_source = $AllViews{$tab}{source};
 
    my $sql_columns;
    for my $tab_column ( keys %CurrentTab ) {
        if ( $sql_columns eq "" ) {
            $sql_columns = "$tab_column";
        }
        else {
            $sql_columns = "$sql_columns, $tab_column";
        }
    }

    if ( $query_source eq "sql" ) {
        $sql = CIViews::sql_stmt("$tab", "$item");
        my $sth = $dbh->prepare($sql) or die "Couldn't prepare query";
        $sth->execute();
        $sth->rows;
        # Display columns vertically - there will be 2 columns Name/Value
        if ( $AllViews{$tab}{orientation} eq "vertical" ) {
            my @row = $sth->fetchrow_array();
            my $column_number = 0; 
            for my $key (sort { $CurrentTab{$a}{order} <=> $CurrentTab{$b}{order} } keys %CurrentTab) {
                my @inv_row = ($CurrentTab{$key}{colname}, @row[$column_number]);  
                push @Rows_AoA, [ @inv_row ]; 
                $column_number++;
            }
        }
        else {
            while (my @row = $sth->fetchrow_array()) {
                push @Rows_AoA, [ @row ];
            }
        }

        $sth->finish();
    }
    elsif ( $query_source eq "external" ) {
        my $rows_aoa_ref = CIViews::external_source("$tab");
        @Rows_AoA = @$rows_aoa_ref;       

    }

    return (\@Rows_AoA, $sql_columns);
}

####################################################
sub search_for {
    my $search_str = shift;
    my $aoa_ref    = shift;

    my @AOA = @$aoa_ref;
    my @NEW_AOA = ();

    foreach my $row_ref (@AOA) {
       my $count = grep ( /$search_str/i, @$row_ref);
       if ( $count != 0 ) {
           push @NEW_AOA, [ @$row_ref ];
       }
    }
    return (\@NEW_AOA);
}
##################################################################
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

################################################################
sub comma_me {
local $_  = shift;
1 while s/^(-?\d+)(\d{3})/$1,$2/;
return $_;
}

################################################################
sub trim {
   my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

