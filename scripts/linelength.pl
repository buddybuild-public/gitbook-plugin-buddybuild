#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Term::ANSIColor;
use lib dirname (__FILE__);
use BB;

our %options;
getopts('hvd:l:', \%options);

usage() if $options{h};

BB::set_verbose($options{v} ? 1 : 0);

my $dir = $options{d} or usage("No scan directory provided!");
my $length = $options{l} || 80;

print "Checking line lengths in '$dir'... ";
BB::DEBUG "\n";
our @files = BB::findadoc($dir);
BB::DEBUG "File scanning complete.\n\n";
my $results = check_length($length, @files);

unless (scalar keys %$results) {
  print color('bold green'), "all files fit within $length columns!", color('reset'), "\n";
  exit 0;
}

print color('bold red'), "Line length violations found!", color('reset'), "\n";
foreach my $file (sort keys %$results) {
  print color('magenta'), $file, color('reset'), "\n";
  foreach my $details (@{ $results->{$file} }) {
    printf "%s%d%s: %s%d%s characters\n", color('green'), $details->{line}, color('reset'),
            color('red'), $details->{chars}, color('reset');
  }
}
exit 1;

sub check_length {
  my $length = shift;

  my %results;
  foreach my $file (@_) {
    BB::DEBUG "Checking line length in '$file'...\n";
    open my $fh, '<', $file
      or die "Couldn't open file '$file': $!\n";
    chomp(my @lines = <$fh>);
    close $fh;

    my $count = 0;
    my $in_source = 0;
    my $delimiter = '';

    foreach my $line (@lines) {
      $count++;
      BB::DEBUG "Line $count: '$line'\n";

      # identify source blocks
      if ($line =~ m/\[source[^\]]*\]/) {
        $in_source = 1;
        next;
      }

      # process source blocks
      if ($in_source) {
        if ($line =~ m/^(-|=)+$/) {
          if (length $delimiter and $delimiter eq $1) {
            BB::DEBUG "End delimiter for source block found.\n";
            $delimiter = '';
            next;
          }
          if ($delimiter eq '') {
            BB::DEBUG "Source block start delimiter found.\n";
            $delimiter = $1;
            next;
          }
        }
        BB::DEBUG "Skipping source content...\n";
        next;
      }

      # Skip titles, because they have to appear on one line
      if ($line =~ m/^=+ /) {
        BB::DEBUG "Skipping title\n";
        next;
      }

      # skip links+images, as they often have long URLs that cannot split
      if ($line =~ m/(link|image):[^\[]+\[/) {
        my $type = $1;
        my $skip = 1;

        if (length $line > $length) {
          my $test = substr($line, 0, $length);
          if ($test =~ m/ /) {
            # link/image has a space we could wrap on, within the length
            $skip = 0;
          }
        }

        if ($skip) {
          BB::DEBUG "Skipping a $type\n";
          next;
        }
      }

      # skip URLs
      if ($line =~ m@(ht|f)tps?://@) {
        BB::DEBUG "Skipping a URL\n";
        next;
      }

      if (length $line > $length) {
        BB::DEBUG "Line length violation for '$line'\n";
        $results{$file} = [] unless exists $results{$file};
        push @{$results{$file}}, {
          line  => $count,
          chars => length $line,
        };
      }
    }
  }
  BB::DEBUG "Done checking line lengths.\n";
  return \%results;
}

sub usage {
  my $msg = shift;

  print "ERROR: $msg\n\n" if $msg;
  print <<USAGE;
Usage:
$0 [-hv] -d <directory to scan> -l <maximum length>

Scans a directory for '*.adoc' files, checks the maximum line length
within each, and emits a report of which lines in which files are
too long.
on each, and emits any spelling errors detected (exit code 1, if so).

Options:
 -h  This help text.
 -d  The directory to scan.
 -l  The line length limit; lines longer than this are reported.
     Defaults to 80.
 -v  Verbose output.
USAGE

  exit $msg ? 1 : 0;
}
