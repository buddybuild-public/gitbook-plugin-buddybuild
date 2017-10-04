#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Spec::Functions;
use Getopt::Std;
use Term::ANSIColor;
use lib dirname (__FILE__);
use BB;

our %options;
getopts('hvd:D:', \%options);

usage() if $options{h};

BB::set_verbose($options{v} ? 1 : 0);

my $dir = $options{d} or usage("No scan directory provided!");
our $dicts = $options{D} or usage("No dictionary path provided!");

my $bbdict = catfile($dicts, 'buddybuild');
my $usdict = catfile($dicts, 'en_US');
our $hunspell_command = "hunspell -d $bbdict,$usdict -l";

print "Checking spelling in '$dir'... ";
BB::DEBUG "\n";
our @files = BB::findadoc($dir);
BB::DEBUG "File scanning complete.\n\n";
my $results = check_spelling(@files);

my $count = scalar keys %{$results->{words}};
unless ($count) {
  print color('bold green'), "No spelling errors found!", color('reset'), "\n";
  exit 0;
}

print color('bold red'), "$count misspelled words found!", color('reset'), "\n";

# Determine the longest misspelling; makes the output nicer
my $maxw = 0;
foreach my $key (keys %{$results->{words}}) {
  my $l = length $key;
  $maxw = $l if $l > $maxw;
}
my $indentw = " " x $maxw;

# Determine the longest filename; makes the output nicer
my $maxf = 0;
foreach my $key (keys %{$results->{files}}) {
  my $l = length $key;
  $maxf = $l if $l > $maxf;
}
my $indentf = " " x $maxf;

# Output the misspellings, and where they appear
print color('bold'), "Misspelled words:", color('reset'), "\n";
foreach my $key (sort keys %{$results->{words}}) {
  my $label = sprintf "%". $maxw ."s", $key;
  my $result = $results->{words}->{$key};
  foreach my $path (sort keys $result) {
    printf "%s%s%s  %2dx %s%s%s\n", color('red'), $label, color('reset'),
            $result->{$path},
            color('magenta'), $path, color('reset');
    $label = $indentw;
  }
}

# Output the files, and the misspellings contained within
print "\n", color('bold'), "Where the misspellings occur:", color('reset'), "\n";
foreach my $key (sort keys %{$results->{files}}) {
  my $label = sprintf "%". $maxf ."s", $key;
  my $result = $results->{files}->{$key};
  foreach my $path (sort keys $result) {
    printf "%s%s%s  %2dx %s%s%s\n", color('magenta'), $label, color('reset'),
            $result->{$path},
            color('red'), $path, color('reset');
    $label = $indentf;
  }
}

exit 1;

sub check_spelling {
  my %results = (
    'words' => {},
    'files' => {},
  );
  my $words = $results{words};
  my $files = $results{files};
  foreach my $file (@_) {
    BB::DEBUG "Checking spelling in '$file'...\n";
    my $command = $hunspell_command ." ". $file;
    my $output = `$command`;
    next unless length $output;
    foreach my $line (split m/\n/, $output) {
      BB::DEBUG "Bad spelling '$line'\n";
      $words->{$line} = {} unless exists $words->{$line};
      $words->{$line}->{$file} = 0 unless exists $words->{$line}->{$file};
      $words->{$line}->{$file}++;

      $files->{$file} = {} unless exists $files->{$file};
      $files->{$file}->{$line} = 0 unless exists $files->{$file}->{$line};
      $files->{$file}->{$line}++;
    }
  }
  BB::DEBUG "Done checking spelling.\n";
  return \%results;
}

sub usage {
  my $msg = shift;

  print "ERROR: $msg\n\n" if $msg;
  print <<USAGE;
Usage:
$0 [-hv] -d <directory to scan> -D <path to dictionaries>

Scans a directory for '*.adoc' files, runs the hunspell spellcheck tool
on each, and emits any spelling errors detected (exit code 1, if so).

Options:
 -h  This help text.
 -d  The directory to scan.
 -D  The path to the hunspell dictionaries.
 -v  Verbose output.
USAGE

  exit $msg ? 1 : 0;
}
