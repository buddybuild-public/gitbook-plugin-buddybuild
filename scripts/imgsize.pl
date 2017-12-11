#!/usr/bin/perl

use strict;
use warnings;

use Cwd 'abs_path';
use Data::Dumper;
use File::Basename;
use File::Spec::Functions;
use Getopt::Std;
use POSIX;
use Term::ANSIColor;
use lib dirname (__FILE__);
use BB;
use Image::Info qw(image_info dim);

our %options;
getopts('hvd:', \%options);

usage() if $options{h};

$SIG{'INT'} = sub {
  print color('reset'), "\nterminated.\n";
  exit 0;
};

BB::set_verbose($options{v} ? 1 : 0);

my $dir = $options{d} or usage("No scan directory provided!");

print "Checking image sizes in '$dir'... ";
BB::DEBUG "\n";
our @adoc = BB::find_files($dir, qr/\.adoc$/);
our @images = BB::find_files($dir, qr/\.(jpg|jpeg|gif|png)$/i);
BB::DEBUG "File scanning complete.\n\n";
my $results = check_sizes($dir, \@adoc, \@images);

unless (scalar keys %$results) {
  print color('bold green'), "none found!", color('reset'), "\n";
  exit 0;
}

print color('bold red'), "some found!", color('reset'), "\n";
foreach my $file (sort keys %$results) {
  print color('magenta'), $file, color('reset'), "\n";

  my $i = $results->{$file};
  foreach my $image (@$i) {
    printf "  %s%d%s: '%s' set=%s%s,%s%s img=%s%d,%d%s\n",
      color('cyan'), $image->{line}, color('reset'),
      $image->{image},
      color('red'), $image->{sw}, $image->{sh}, color('reset'),
      color('green'), $image->{aw}, $image->{ah}, color('reset')
    ;
  }
}

exit 1;

sub check_sizes {
  my ($dir, $adoc, $images) = @_;

  my $abs_dir = abs_path($dir);

  my %image_map;
  foreach my $image (@$images) {
    my $relative_path = File::Spec->abs2rel($image, $dir);
    $image_map{$relative_path} = 1;
  }

  my %results;

  BB::DEBUG "Scanning Asciidoc files for image references...\n";
  foreach my $file (@$adoc) {
    BB::DEBUG "Checking image sizes in '$file'...\n";
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
      my $attributes = $'; # Everything after the match above.
      next if $image =~ m@^https?://@; # don't check sizes of remote images

      # Assemble the image's attributes, which may span multiple lines.
      my $contender = $attributes;
      my $offset = 0;
      while ($contender !~ m/\]/) {
        $contender = $lines[$count + $offset++];
        $attributes .= $contender;
      }
      $attributes =~ s/\].*$//;
      BB::DEBUG "Attributes for '$image': $attributes\n";

      # Remove quoted alt text content to avoid bad split later.
      $attributes =~ s/"(.*?)"/"-"/;

      my @attr = split m/\s*,\s*/, $attributes;
      my $width = "na";
      my $height = $width;
      if (scalar @attr > 2) {
        $width = int($attr[1]);
        $height = int($attr[2]);
      }
      BB::DEBUG "Image specified width=$width, height=$height\n";

      # Convert referenced image path into canonical relative path
      my $referenced_path = File::Spec->abs2rel(
        abs_path(
          catfile($file_path, $image)
        ), $abs_dir
      );

      # Get the image's dimensions
      my $img_info = image_info($referenced_path);
      my ($iw, $ih) = dim($img_info);
      BB::DEBUG "Image physical width=$iw, height=$ih\n";

      my $dots = 72;
      my $units = 'dpi';
      if (exists $img_info->{resolution}) {
        ($dots, $units) = split m/ /, $img_info->{resolution};
        $dots = 72 if $dots eq '1/1' or $dots =~ m/^ARRAY/;
        $units //= "unknown";
      }
      BB::DEBUG "dots='$dots', units='$units'\n";

      my $dpi = $dots;
      $dpi /= 39.3701 if $units eq 'dpm';
      $dpi *= 2.54 if $units eq 'dpcm';
      if ($dpi > 96) {
        $iw = ceil($iw / 2);
        $ih = ceil($ih / 2);
      }
      BB::DEBUG "Image visible width=$iw, height=$ih (at $dpi dpi)\n";

      if (($width eq "na" or $width != $iw)
          or ($height eq "na" or $height != $ih)) {
        BB::DEBUG "===== Size mismatch!\n";
        $results{$file} = [] unless exists $results{$file};

        push @{ $results{$file} }, {
          image => $image,
          path  => $referenced_path,
          line  => $count,
          sw    => $width,
          sh    => $height,
          aw    => $iw,
          ah    => $ih,
        };
      }
    }
  }

  BB::DEBUG "Done checking image sizes.\n";
  return \%results;
}

sub usage {
  my $msg = shift;

  print "ERROR: $msg\n\n" if $msg;
  print <<USAGE;
Usage:
$0 [-hv] -d <directory to scan>

Scans the directory for '*.adoc' files, and for 'image' files, and
reports any images where the specified size differs from the actual size.

Options:
 -h  This help text.
 -d  The directory to scan.
 -v  Verbose output.
USAGE

  exit $msg ? 1 : 0;
}
