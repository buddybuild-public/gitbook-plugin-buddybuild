#!/usr/bin/perl

use strict;
use warnings;

use File::Spec::Functions;
use Getopt::Std;

our %options;
getopts('hvd:', \%options);

usage() if $options{h};

our $VERBOSE = $options{v} ? 1 : 0;

sub DEBUG {
  return unless $VERBOSE;
  print $_ for @_;
}

my $dir = $options{d} or usage("No scan directory provided!");
my $length = $options{l} || 80;

print "Checking for unassigned image alt text in '$dir'... ";
DEBUG "\n";
our @files = findadoc($dir);
DEBUG "File scanning complete.\n\n";
my $results = check_alt($length, @files);

unless (scalar keys %$results) {
  print "None found!\n";
  exit 0;
}

print "Unassigned image alt text found!\n";
foreach my $file (sort keys %$results) {
  print "In '$file':\n";
  foreach my $details (@{ $results->{$file} }) {
    printf "  Line %d: %d characters\n", $details->{line}, $details->{chars};
  }
}
exit 1;

sub findadoc {
  my $dir = shift;

  my @files;
  DEBUG "Scanning '$dir'...\n";
  opendir(my $dh, $dir)
    or die "Cannot open directory '$dir': $!\n";

  while (my $file = readdir $dh) {
    next if $file eq '.';
    next if $file eq '..';

    my $path = catfile($dir, $file);
    if (-d $path) {
      push @files, findadoc($path);
      next;
    }
    next unless $file =~ m/\.adoc$/;
    DEBUG "Found '$path'\n";
    push @files, $path;
  }

  closedir $dh;
  return @files;
}

sub check_alt {
  my $length = shift;

  my %results;
  foreach my $file (@_) {
    DEBUG "Checking for unassigned image alt text in '$file'...\n";
    open my $fh, '<', $file
      or die "Couldn't open file '$file': $!\n";
    chomp(my @lines = <$fh>);
    close $fh;

    my $count = 0;
    my $delimiter = '';

    foreach my $line (@lines) {
      $count++;
      DEBUG "Line $count: '$line'\n";

      # identify source blocks
      if ($line =~ m/image:.+\[(,|"\s*",)/) {
        DEBUG "Unassigned alt text found in '$line'\n";
        $results{$file} = [] unless exists $results{$file};
        push @{$results{$file}}, {
          line  => $count,
          chars => length $line,
        };
      }
    }
  }
  DEBUG "Done checking unassigned alt text.\n";
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
