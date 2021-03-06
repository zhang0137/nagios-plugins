#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2013-07-28 17:08:27 +0100 (Sun, 28 Jul 2013)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#  

$DESCRIPTION = "Nagios Plugin to check given HBase table(s) via the JSP interface on the HBase Master

Checks:

1. Table exists
2. Table is enabled and available (has at least one region listed, disabled tables have no regions listed)

Strongly recommended to use check_hbase_table.pl instead which uses the HBase Thrift API, it's must tighter programmatically, this is only doing a basic scrape of the HBase Master JSP which could break across releases. The only advantage this program has is that it doesn't require having an HBase Thrift Server

Written and tested on CDH 4.3 (HBase 0.94.6-cdh4.3.0). Also tested on CDH 4.4.0

Limitations:

1. If RegionServers are down you may get a timeout when querying the HBase Master JSP for the table details (CRITICAL: '500 read timeout'). The Stargate handles this better (check_hbase_tables_stargate.pl)";

$VERSION = "0.3";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;
# Mojo::DOM causes this error on Mac OSX 10.8: Your vendor has not defined Time::HiRes macro CLOCK_MONOTONIC, used at (eval 11) line 1.
#use Mojo::DOM;
#use HTML::TreeBuilder;
use LWP::UserAgent;

my $default_port = 60010;
$port = $default_port;

my $tables;

%options = (
    "H|host=s"         => [ \$host,     "HBase Master to connect to" ],
    "P|port=s"         => [ \$port,     "HBase Master JSP Port to connect to (defaults to $default_port)" ],
    "T|tables=s"       => [ \$tables,   "Table(s) to check. This should be a list of user tables, not -ROOT- or .META. catalog tables which are checked additionally. If no tables are given then only -ROOT- and .META. are checked" ],
);

@usage_order = qw/host port tables/;
get_options();

$host       = validate_host($host);
$port       = validate_port($port);
my @tables = qw/-ROOT- .META./;
push(@tables, split(/\s*,\s*/, $tables)) if defined($tables);
@tables or usage "no valid tables specified";
@tables = uniq_array @tables;
my $table;
foreach $table (@tables){
    if($table =~ /^(-ROOT-|\.META\.)$/){
    } else {
        $table = isDatabaseTableName($table) || usage "invalid table name $table given";
    }
}

vlog_options "tables", "[ " . join(" , ", @tables) . " ]";
vlog2;
set_timeout();

my $ua_timeout = $timeout / 2;
$ua_timeout = 1 if ($ua_timeout < 1);

my $ua = LWP::UserAgent->new;
$ua->agent("Hari Sekhon $progname $main::VERSION");
$ua->timeout($ua_timeout);
$ua->show_progress(1) if $debug;

$status = "OK";

my $url;
my $html_tree;

my @tables_ok;
my @tables_not_enabled;
my @tables_not_found;
my @tables_not_available;

validate_resolvable($host);
foreach $table (@tables){
    $url = "http://$host:$port/table.jsp?name=$table";
    vlog2 "querying HBase Master for table $table";
    vlog3 "url: $url";
    my $res = $ua->get($url);
    vlog2 "got response";
    my $status_line  = $res->status_line;
    vlog2 "status line: $status_line";
    my $content = $res->content;
    vlog3 "\ncontent:\n\n$content\n";
    vlog2;

    unless($res->code eq 200){
        if($res->code eq 500 and $content =~ /TableNotFoundException/){
            critical;
            vlog2 "table not found: $table\n";
            push(@tables_not_found, $table);
            next;
        } else {
            quit "CRITICAL", "'$status_line'";
        }
    }
    if($content =~ /\A\s*\Z/){
        quit "CRITICAL", "empty body returned from '$url'";
    }

    #$dom = Mojo::DOM->new($content);
    #$html_tree = HTML::TreeBuilder->new_from_content($content);
    # Check we have a regionserver listed for the table, this only happens when the table exists and is available and has a region assigned to a regionserver
    if($table ne "-ROOT-" and $table ne ".META." and $content !~ /<td>Enabled<\/td>\s*<td>true<\/td>/i){
        vlog2 "table '$table' not enabled";
        push(@tables_not_enabled, $table);
    } elsif($content =~ /<tr>            [\r\n\s]*
                        <td>
                            $table(?:,[^,]*,[\w\.]+)?
                        <\/td>      [\r\n\s]*
                        <td>        [\r\n\s]*
                            <a\s+href="[^"]+">[^<]+<\/a>    [\r\n\s]*
                        <\/td>/xim){
        vlog2 "found table '$table' and available regions";
        push(@tables_ok, $table);
    } else {
        critical;
        vlog2 "table '$table' exists but no available regions";
        push(@tables_not_available, $table);
    }
    vlog2;
}

$msg = "HBase ";

sub print_tables($@){
    my $str = shift;
    my @arr = @_;
    if(@arr){
        @arr = uniq_array @arr;
        plural scalar @arr;
        $msg .= "table$plural $str: " . join(" , ", @arr) . " -- ";
    }
}

print_tables("not found",     @tables_not_found);
print_tables("not enabled",   @tables_not_enabled);
print_tables("not available", @tables_not_available);
print_tables("ok",            @tables_ok);
$msg =~ s/ -- $//;

quit $status, $msg;
