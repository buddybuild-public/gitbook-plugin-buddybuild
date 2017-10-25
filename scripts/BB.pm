package BB;

use strict;
use warnings;

use File::Spec::Functions;
use Term::ANSIColor;

our $VERBOSE = 0;

sub set_verbose {
  $VERBOSE = shift;
  return $VERBOSE;
}

sub DEBUG {
  return unless $VERBOSE;
  print color('blue') if scalar @_;
  print $_ for @_;
  print color('reset') if scalar @_;
}

sub findadoc {
  my $dir = shift;

  my $regex = qr/\.adoc$/;
  return find_files($dir, $regex);
}

sub find_files {
  my $dir = shift;
  my $regex = shift;

  my @files;
  DEBUG "Scanning '$dir'...\n";
  opendir(my $dh, $dir)
    or die "Cannot open directory '$dir': $!\n";

  while (my $file = readdir $dh) {
    next if $file eq '.';
    next if $file eq '..';
    next if $file =~ m/^(node_modules|\.git|_book|_css|_js)$/;

    my $path = catfile($dir, $file);
    if (-d $path) {
      push @files, find_files($path, $regex);
      next;
    }
    next unless $file =~ m/$regex/;
    DEBUG "Found '$path'\n";
    push @files, $path;
  }

  closedir $dh;
  return @files;
}

1;
