#!/bin/env perl
# Written by: Michael Rollins @Indeed.com 12-12-13
# Written to quickly convert existing nagios definitions (*.cfg) 
# into comparable puppet declarations using puppet's nagios module

use strict;
#use warnings;

use Carp;
use Data::Dumper;

our (@lines,@files);
our $output = "\n";
our $title_keyword = 'service_description';
# Update keyword if needed and get files to parse
if ("$ARGV[0]" eq "-t") {
    shift @ARGV;
    $title_keyword = shift @ARGV;
    warn "Setting title keyword to $title_keyword\n";
    @files = @ARGV;
} elsif (-e "$ARGV[0]") {
    @files = @ARGV;
} else {
    usage('Invalid options');
}
#croak Dumper(\@files);
# open each CFG file provided and parse them all at once
foreach my $file (@files) {
    open(my $fh, "<", "$file")
        or die "cannot open < $file: $!";
    while (<$fh>) {
        push @lines, $_;
    }
}
#print Dumper(\@lines);
# Generate output strings for each line parsed
my $num = 0;
for my $line (@lines) {
    $num++;
    next if ($line =~ m/(^#|^\s+#|^$)/);
    $output .= get_str($num,$line);
}
print $output;

sub get_str {
    my $ndx = shift;
    my $line = shift;

    $line =~ s/'/"/g;   # Make sure we are using double quotes before adding single quotes to values
    $line =~ s/define /nagios_/;    # Replace nagios define with puppet nagios_
    if ($line =~ m/(^\tuse)/) {
        $line =~ s/^\t(\w+)(\s+)(\S.*)$/\t$1\t\t\t=> '$3',/g;   # generate quoted key/values with big arrow
    } elsif ($line =~ m/(^\thost_name|^\tcheck_command|^\tregister)/) {
        $line =~ s/^\t(\w+)(\s+)(\S.*)$/\t$1\t\t=> '$3',/g;
    } else {
        $line =~ s/^\t(\w+)(\s+)(\S.*)$/\t$1\t=> '$3',/g;
    }
    $line =~ s/\}/\}\n/;
    if ($line =~ m/nagios_/) {
        my $title = get_title($ndx);
        $line =~ s/\{$/\{'$title':/;
    }
    return $line;
}

sub get_title {
    my $ndx = shift;
    my $max = $ndx + 5;
    my $title;
    foreach (@lines[$ndx..$max]) {      # Search the next few lines for the value we want as the title
        if (m/^\t$title_keyword\s+(\S.*)$/) {
            $title = $1;
            last;
        }
    }
    return $title;
}

sub usage {
    my $msg = shift;
    warn "\n$msg\n" if $msg;
print STDERR <<EOM;

This tool reads multiple Nagios CFG files and generates valid puppet declarations for the same types.
A title is applied automatically per puppet resource requirements, keyword can be specified which determines
where the value comes from.
Outputs to standard out, for easy piping or redirection to a file.

Usage:
    $0 [-t title_keyword] host.cfg service.cfg template.cfg command.cfg 

Options:
    "-t"    If the first argument is a '-t' then the second argument is assumed to be the keyword used to find
            the title which will be applied to the puppet declaration.  The remaining arguments are considered
            file names which should be parsed. Default: service_description

            All arguments are considered nagios CFG files, unless the first is '-t'

EOM
    exit 1; 
}
