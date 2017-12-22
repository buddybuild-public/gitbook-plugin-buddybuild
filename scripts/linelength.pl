#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Term::ANSIColor;
use lib dirname (__FILE__);
use BB;
use YAML::Tiny;

our %options;
getopts('hvd:l:t:s:', \%options);

usage() if $options{h};

BB::set_verbose($options{v} ? 1 : 0);

my $dir = $options{d} or usage("No scan directory provided!");
my $length = $options{l} || 80;

our %meta = (
  titletext   => ($options{t} || 75),
  description => ($options{s} || 155),
);

our $violations = 0;

print "Checking line lengths in '$dir'... ";
BB::DEBUG "\n";
our @files = BB::findadoc($dir);
BB::DEBUG "File scanning complete.\n\n";
my $results = check_length($length, @files);

unless (scalar keys %$results) {
  print color('bold green'), "all files fit!", color('reset'), "\n";
  exit 0;
}

print color('bold red'), "$violations line length violations found!",
      color('reset'), "\n";
foreach my $file (sort keys %$results) {
  print color('magenta'), $file, color('reset'), "\n";
  foreach my $details (@{ $results->{$file} }) {
    printf "%s%d%s: %s%d%s/%s%d%s characters\n",
      color('green'), $details->{line}, color('reset'),
      color('red'), $details->{chars}, color('reset'),
      color('blue'), $details->{limit}, color('reset');
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
    my $in_yaml = 0;
    my @yaml;
    my $delimiter = '';

    foreach my $line (@lines) {
      $count++;
      BB::DEBUG "Line $count: '$line'\n";

      # identify YAML preamble
      if ($count == 1 and $line =~ m/---/) {
        $in_yaml = 1;
        next;
      }

      # identify source blocks
      if ($line =~ m/\[source[^\]]*\]/) {
        $in_source = 1;
        next;
      }

      # process YAML preamble
      if ($in_yaml) {
        if ($line =~ m/---/) {
          BB::DEBUG "End delimiter for YAML preamble found.\n";
          $in_yaml = 0;

          my $yaml = YAML::Tiny->read_string(join "\n", @yaml);
          my $config = $yaml->[0];
          foreach my $key (sort keys %meta) {
            my $value = $config->{$key};
            my $len   = (length $value) || 0;
            if ($len > $meta{$key}) {
              BB::DEBUG "Meta $key too long ($len/$meta{$key}) for '$value'\n";
              $results{$file} = [] unless exists $results{$file};
              push @{$results{$file}}, {
                line  => $count,
                chars => $len,
              };
              $violations++;
            }
          }

          next;
        }

        push @yaml, $line;
        next;
      }

      # process source blocks
      if ($in_source) {
        if ($line =~ m/^(-|=)+$/) {
          if (length $delimiter and $delimiter eq $1) {
            BB::DEBUG "End delimiter for source block found.\n";
            $delimiter = '';
            $in_source = 0;
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
          if ($test =~ m/:.* /) {
            # link/image has a space after the colon that we could wrap
            # on, within the length
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
          limit => $length,
        };
        $violations++;
      }
    }
  }
  BB::DEBUG "Done checking line lengths.\n";
  return \%results;
}

sub trim {
  my $string = shift;
  $string =~ s/^\s+|\s+$//g;
  return $string;
}

sub usage {
  my $msg = shift;

  print "ERROR: $msg\n\n" if $msg;
  print <<USAGE;
Usage:
$0 [-hv] -d <directory to scan> [-l <max line length>] \
   [-s <max description tag length>] [-t <max title tag length>]

Scans a directory for '*.adoc' files, checks the maximum line length
within each, and emits a report of which lines in which files are
too long. Also checked is the length of the meta tags 'title' and
'description' that may be specified in the YAML preamble.

Options:
 -h  This help text.
 -d  The directory to scan.
 -l  The line length limit; lines longer than this are reported.
     Defaults to 80.
 -s  The length limit for meta description text. Defaults to 155.
 -t  The length limit for meta title text. Defaults to 75.
 -v  Verbose output.
USAGE

  exit $msg ? 1 : 0;
}
