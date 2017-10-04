#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Term::ANSIColor;
use lib dirname (__FILE__);
use BB;

our %options;
getopts('hvd:', \%options);

usage() if $options{h};

BB::set_verbose($options{v} ? 1 : 0);

my $dir = $options{d} or usage("No scan directory provided!");
my $length = $options{l} || 80;

print "Checking for unassigned image alt text in '$dir'... ";
BB::DEBUG "\n";
our @files = BB::findadoc($dir);
BB::DEBUG "File scanning complete.\n\n";
my $results = check_alt($length, @files);

unless (scalar keys %$results) {
  print color('bold green'), "none found!", color('reset'), "\n";
  exit 0;
}

print color('bold red'), "problems found!", color('reset'), "\n";
my $count = 0;
foreach my $file (sort keys %$results) {
  print color('magenta'), "$file", color('reset'), "\n";
  foreach my $details (@{ $results->{$file} }) {
    printf "%s%d%s: %s\n", color('green'), $details->{line}, color('reset'), $details->{text};
    $count++;
  }
}
print color('bold red'), $count, color('reset bold'), " to be fixed.",
      color('reset'), "\n";
exit 1;

sub check_alt {
  my $length = shift;

  my %results;
  foreach my $file (@_) {
    BB::DEBUG "Checking for unassigned image alt text in '$file'...\n";
    open my $fh, '<', $file
      or die "Couldn't open file '$file': $!\n";
    chomp(my @lines = <$fh>);
    close $fh;

    my $count = 0;
    my $delimiter = '';

    foreach my $line (@lines) {
      $count++;
      BB::DEBUG "Line $count: '$line'\n";

      # identify source blocks
      if ($line =~ m/image:.+\[(,|"\s*",)/) {
        BB::DEBUG "Unassigned alt text found in '$line'\n";
        $results{$file} = [] unless exists $results{$file};
        push @{$results{$file}}, {
          line  => $count,
          text => $line,
        };
      }
    }
  }
  BB::DEBUG "Done checking unassigned alt text.\n";
  return \%results;
}

sub usage {
  my $msg = shift;

  print "ERROR: $msg\n\n" if $msg;
  print <<USAGE;
Usage:
$0 [-hv] -d <directory to scan>

Scans a directory for '*.adoc' files, checks each file for unassigned
alt text, and emits a report of which lines in which files contain such.

Options:
 -h  This help text.
 -d  The directory to scan.
 -v  Verbose output.
USAGE

  exit $msg ? 1 : 0;
}
