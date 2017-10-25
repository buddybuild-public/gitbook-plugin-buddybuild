#!/usr/bin/perl

use strict;
use warnings;

use Cwd 'abs_path';
use File::Basename;
use File::Spec::Functions;
use Getopt::Std;
use Term::ANSIColor;
use lib dirname (__FILE__);
use BB;

our %options;
getopts('hvd:', \%options);

usage() if $options{h};

$SIG{'INT'} = sub {
  print color('reset'), "\nterminated.\n";
  exit 0;
};

BB::set_verbose($options{v} ? 1 : 0);

my $dir = $options{d} or usage("No scan directory provided!");

print "Checking for unused images in '$dir'... ";
BB::DEBUG "\n";
our @adoc = BB::find_files($dir, qr/\.adoc$/);
our @images = BB::find_files($dir, qr/\.(jpg|jpeg|gif|png)$/i);
BB::DEBUG "File scanning complete.\n\n";
my $results = check_images($dir, \@adoc, \@images);

unless ( scalar keys %$results) {
  print color('bold green'), "none found!", color('reset'), "\n";
  exit 0;
}

print color('bold red'), "some found!", color('reset'), "\n";
foreach my $unused (sort keys %$results) {
  print color('magenta'), $unused, color('reset'), "\n";
}
exit 1;

sub check_images {
  my ($dir, $adoc, $images) = @_;

  my $abs_dir = abs_path($dir);

  my %image_map;
  foreach my $image (@$images) {
    my $relative_path = File::Spec->abs2rel($image, $dir);
    $image_map{$relative_path} = 1;
  }

  my %used;
  my %results;

  BB::DEBUG "Scanning Asciidoc files for image references...\n";
  foreach my $file (@$adoc) {
    BB::DEBUG "Checking image use in '$file'...\n";
    open my $fh, '<', $file
      or die "Couldn't open file '$file': $!\n";
    chomp(my @lines = <$fh>);
    close $fh;
    my $file_path = dirname($file);

    my $count = 0;
    foreach my $line (@lines) {
      $count++;

      # skip everything but image macros
      next unless $line =~ m/image:([^\[]+)\[/;

      my $image = $1;
      next if $image =~ m@^https?://@; # URLs should be fine.

      # Convert referenced image path into canonical relative path
      my $referenced_path = File::Spec->abs2rel(
        abs_path(
          catfile($file_path, $image)
        ), $abs_dir
      );

      $used{$referenced_path} = 1
        if exists $image_map{$referenced_path};

      # We use HTMLProofer, so we don't care about missing images here.
    }
  }

  BB::DEBUG "Scanning image list for unused images...\n";
  foreach my $image (sort keys %image_map) {
    next if exists $used{$image};

    $results{$image} = 1;
  }

  BB::DEBUG "Done checking images.\n";
  return \%results;
}

sub usage {
  my $msg = shift;

  print "ERROR: $msg\n\n" if $msg;
  print <<USAGE;
Usage:
$0 [-hv] -d <directory to scan> -l <maximum length>

Scans the directory for '*.adoc' files, and for 'image' files, and
reports any images that are unused by the doc source.

Options:
 -h  This help text.
 -d  The directory to scan.
 -v  Verbose output.
USAGE

  exit $msg ? 1 : 0;
}
