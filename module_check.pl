﻿#!/usr/local/bin/perl

use warnings;
use strict;
use v5.10;

use File::Find;
use File::Basename;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use File::stat;
use POSIX;

my $VERSION = 0.01;

use constant TRUE  => 1;
use constant FALSE => 0;

my $errors;
my $vfiles;
my $nonVmods;
my $gCount;
my $manager;
my $list;
my $time;
my $help;
my $debug;

GetOptions(
            "count"    => \$gCount,
            "errors"   => \$errors,
            "files"    => \$vfiles,
            "folders"  => \$nonVmods,
            "manager"  => \$manager,
            'list'     => \$list,
            'time'     => \$time,
            'debug'    => \$debug,
            "help|?|h" => \$help,
          );
pod2usage(1) if $help;

my @version_files;    # The list of all version files.
my %mods
  ; # The full hash of folders.  (And whether they contain version files in any subfolder.)
my @gamedata;          # The locations of GameData folders.
my @module_manager;    # The list of all Module Manager installs.

foreach (@ARGV) {
    find( {
             preprocess  => \&filters,
             wanted      => \&search,
             postprocess => \&after
          },
          $_
        );
}

# Pare down the list to only the top-level directories.
my @not_toplevel = grep { $_ !~ m|GameData/[^/]+$| } keys %mods;
delete @mods{@not_toplevel};

print "\nCount of GameData folders (should be 1): " . scalar @gamedata . "\n"
  if ( $gCount or ( $errors and @gamedata > 1 ) );

if ( $errors and @gamedata > 1 ) {
    print "\nGameData folders found at:\n";
    say '==========================';
    print sort map { "$_\n" } @gamedata;
} ## end if ( $errors and @gamedata...)

if ( $manager or ( @module_manager > 1 and $errors ) ) {
    print "\nModule Manager found at:\n";
    say '========================';
    print sort map { "$_\n" } @module_manager;
} ## end if ( $manager or ( @module_manager...))

if ($vfiles) {
    print "\nList of version files:\n";
    say '======================';
    print sort map { fileparse($_) . "\n" } @version_files;
} ## end if ($vfiles)

if ($nonVmods) {
    print "\nList of directories without version files:\n";
    say '===========================================';
    my @folder_list =
      sort grep { $mods{$_}[0] eq FALSE } keys %mods;
    print map { fileparse($_) . "\n" } @folder_list;
} ## end if ($nonVmods)

if ($list) {
    print
      "\nList of folders in GameData, and whether they hold .version files:\n";
    say '================================================================';
    print map {
        ( $mods{$_}[0] ? 'Versioned: ' : 'Not versioned: ' )
          . fileparse($_) . "\n"
    } sort keys %mods;
} ## end if ($list)

if ($time) {
    print "\nLast modified times for all top-level directories:\n";
    say '==================================================';
    print sort map {
            strftime( '%Y-%m-%d %H:%M', localtime( $mods{$_}[1] ) ) . ' - '
          . fileparse($_) . "\n"
    } keys %mods;
} ## end if ($time)

print Dumper \%mods if ($debug);

exit;

sub filters {

    # Set that we haven't seen a version file here yet.
    $mods{$File::Find::dir} = [FALSE];

    # Record the modified timestamp.
    my $st = stat($File::Find::dir)
      or warn "Can't get timestamp on $File::Find::dir: $!";
    $mods{$File::Find::dir}[1] = $st->mtime;

    # Grab GameData folder locations.
    if ( $File::Find::dir =~ m/GameData$/ ) {
        push @gamedata, $File::Find::dir;
    }

# Return the list.
# We're checking all visible (not hidden) folders that aren't PluginData or Squad.
  return grep { $_ !~ m/^PluginData$|^\.|^Squad$/ } @_;
} ## end sub filters

sub search {

    # Set directory modified date to the most recent file in it.
    my $st = stat($_)
      or warn "Can't get timestamp on $_: $!";
    $mods{$File::Find::dir}[1] = $st->mtime
      if ( $st->mtime > ( $mods{$File::Find::dir}[1] // 0 ) );

    # Check to see if this is a version file.
    if ( $_ =~ m/\.version$/ ) {
        push @version_files, $File::Find::name;
        $mods{$File::Find::dir}[0] = TRUE;
    }

    # Check to see if this is a copy of Module Manager.
    if ( $_ =~ m/ModuleManager\..*\.dll/ ) {
        push @module_manager, $File::Find::name;
    }
  return;
} ## end sub search

sub after {
    my ( undef, $parent ) = fileparse($File::Find::dir);
    chop
      $parent;   # ::dir always ends with a directory separator, ::name without.

    # If any subfolder has a version file, we count it.
    $mods{$parent}[0] = TRUE if ( $mods{$File::Find::dir}[0] eq TRUE );

    # Set directory modified date to the most recent file/directory in it.
    $mods{$parent}[1] = $mods{$File::Find::dir}[1]
      if ( $mods{$File::Find::dir}[1] > ( $mods{$parent}[1] // 0 ) );

  return;
} ## end sub after