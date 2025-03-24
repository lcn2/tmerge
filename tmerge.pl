#!/usr/bin/env perl
#
# tmerge - merge one tree into another
#
# Copyright (c) 2005-2007,2015,2023,2025 by Landon Curt Noll.  All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#       supporting documentation
#       source copies
#       source works derived from this source
#       binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# chongo (Landon Curt Noll, http://www.isthe.com/chongo/index.html) /\oo/\
#
# Share and enjoy! :-)

# requirements
#
use strict;
use bytes;
use vars qw($opt_v $opt_V $opt_h $opt_a $opt_f $opt_n $opt_k);
use Getopt::Long qw(:config no_ignore_case);
use File::Find;
no warnings 'File::Find';
use File::Copy;

# version
#
my $VERSION = "1.7.1 2025-03-23";

# my vars
#
# NOTE: We will only cd into dirs whose name is only [-+\w\s./] chars
my $untaint = qr|^([-+\w\s./][-+~\w\s./]*)$|; 	# untainting path pattern
my $srcdir;				# what is being moved
my $destdir;			# where files are being moved to
my $destdev;			# device of $destdir
my $destino;			# inode number of $destdir
my $left_behind = 0;		# number of files left behind under srcdir
my $dir_behind = 0;		# number of directories left behind under srcdir
my $just_rmdir = 0;		# 1 ==> rmdir empty subdirs under srcdir

# usage and help
#
my $usage = "$0 [-a] [-f] [-k] [-n] [-h] [-v lvl] [-V] srcdir destdir";
my $help = qq{$usage

	-h	     print this help message
	-v lvl 	     verbose / debug level
	-V	     print version and exit

	-n	     do not move anything, just print cmds (def: move)

	-a	     don't abort/exit after a fatal error (def: do)
	-f	     force override of existing files (def: don't)
	-k	     keep empty srcdir subdirs (def: rmdir them)

	srcdir	     source directory from which to merge
	destdir	     destination directory

    NOTE:
	exit 0	all is OK
	exit 1	some files were left behind
	exit 2	some directories were left behind
	exit >2 some fatal error

Version: $VERSION};
my %optctl = (
    "a" => \$opt_a,
    "f" => \$opt_f,
    "k" => \$opt_k,
    "n" => \$opt_n,
    "h" => \$opt_h,
    "v=i" => \$opt_v,
    "V" => \$opt_V,
);


# function prototypes
#
sub wanted($);


# setup
#
MAIN: {
    my %find_opt;	# File::Find directory tree walk options

    # setup
    #
    select(STDOUT);
    $| = 1;

    # set the defaults
    #
    $opt_v = 0;

    # parse args
    #
    if (!GetOptions(%optctl)) {
	print STDERR "# $0: invalid command line\nusage:\n\t$help\n";
	exit(3);
    }
    if (defined $opt_h) {
	# just print help, no error
	print STDERR "# $0: usage: $help\n";
	exit(0);
    }
    if (defined $opt_V) {
	print "$VERSION\n";
	exit(0);
    }
    if (! defined $ARGV[0] || ! defined $ARGV[1]) {
	print STDERR "# $0: missing args\nusage:\n\t$help\n";
	exit(4);
    }
    if (defined $ARGV[2]) {
	print STDERR "# $0: too many args\nusage:\n\t$help\n";
	exit(5);
    }
    # canonicalize srcdir removing leading ./'s, multiple //'s, trailing /'s
    $srcdir = $ARGV[0];
    $srcdir =~ s|^(\./+)+||;
    $srcdir =~ s|//+|/|g;
    $srcdir =~ s|(.)/+$|$1|;
    # canonicalize destdir removing leading ./'s, multiple //'s, trailing /'s
    $destdir = $ARGV[1];
    $destdir =~ s|^(\./+)+||;
    $destdir =~ s|//+|/|g;
    $destdir =~ s|(.)/+$|$1|;
    if ($opt_v > 0) {
	print "# DEBUG: -v $opt_v $srcdir $destdir\n";
    }
    if ($opt_v > 2) {
	print "# DEBUG: srcdir: $srcdir\n";
	print "# DEBUG: destdir: $destdir\n";
    }

    # setup to walk the srcdir
    #
    $find_opt{wanted} = \&wanted; # call this on each non-pruned node
    $find_opt{bydepth} = 0;	# walk from top down, not from bottom up
    $find_opt{follow} = 0;	# do not follow symlinks
    $find_opt{no_chdir} = 0;	# OK to chdir as we walk the tree
    $find_opt{untaint} = 1;	# untaint dirs we chdir to
    $find_opt{untaint_pattern} = $untaint; # untaint pattern
    $find_opt{untaint_skip} = 0; # do not skip any dir that is tainted

    # untaint $srcdir, and $destdir
    #
    if ($srcdir =~ /$untaint/o) {
    	$srcdir = $1;
    } else {
	print STDERR "# $0: bogus chars in srcdir\n";
	exit(6);
    }
    if ($destdir =~ /$untaint/o) {
    	$destdir = $1;
    } else {
	print STDERR "# $0: bogus chars in destdir\n";
	exit(7);
    }

    # record the device and inode number of $destdir
    #
    ($destdev, $destino,) = stat($destdir);
    if (! defined $destdev || ! defined $destdev) {
	print STDERR "# $0: destdir not found\n";
	exit(8);
    }

    # walk the srcdir, making renamed copies and symlinks
    #
    find(\%find_opt, $srcdir);
    if ($left_behind > 0) {
	print STDERR "# $0: left $left_behind file(s) behind under $srcdir\n";
	exit(1);
    }

    # clean out empty srcdir subdirectories unless -c
    #
    if (! $opt_k) {
	$just_rmdir = 1;	# let find_opt know we should remove empty dirs
	$find_opt{bydepth} = 0;	# walk from bottom up to clean empty dirs
	find(\%find_opt, $srcdir);
	if ($dir_behind > 0) {
	    print STDERR "# $0: left $dir_behind director(ies) " .
	    		 "behind under $srcdir\n";
	    exit(2);
	}
    }

    # all done
    #
    exit(0);
}


# wanted - File::Find tree walking function called at each non-pruned node
#
# This function is a callback from the File::Find directory tree walker.
# It will walk the $srcdir and copy/rename files as needed.
#
# uses these globals:
#
#	$srcdir		where images are from
#	$destdir	where copied and renamed files go
#	$untaint	untainting path pattern
#
####
#
# NOTE: The File::Find calls this function with this argument:
#
#	$_			current filename within $File::Find::dir
#
# and these global vaules set:
#
#	$srcdir			where images are from
#	$destdir		where copied and renamed files go
#	$File::Find::dir	current directory name
#	$File::Find::name 	complete pathname to the file
#	$File::Find::prune	set 1 one to prune current node out of path
#	$File::Find::topdir	top directory path ($srcdir)
#	$File::Find::topdev	device of the top directory
#	$File::Find::topino	inode number of the top directory
#
sub wanted($)
{
    my $filename = $_;		# current filename within $File::Find::dir or
    my $pathname;		# complete path $File::Find::name
    my $nodedev;		# device of the current file
    my $nodeino;		# inode number of the current file
    my $name;			# path starting from $srcdir
    my $destpath;		# the full path of the destination file

    # canonicalize the path by removing leading ./'s, multiple //'s
    # and trailing /'s
    #
    print "# DEBUG: in wanted arg: $filename\n" if $opt_v > 4;
    print "# DEBUG: File::Find::name: $File::Find::name\n" if $opt_v > 3;
    ($pathname = $File::Find::name) =~ s|^(\./+)+||;
    $pathname =~ s|//+|/|g;
    $pathname =~ s|(.)/+$|$1|;
    print "# DEBUG: pathname: $pathname\n" if $opt_v > 2;

    # untaint pathname
    #
    if ($pathname =~ /$untaint/o) {
    	$pathname = $1;
    } else {
	print STDERR "# $0: Fatal: strange chars in pathname \n";
	print STDERR "# $0: tainted destpath prune near exit(9) $pathname\n";
	$File::Find::prune = 1;
	exit(9) unless defined $opt_a;
	return;
    }

    # ignore names that match common directories
    #
    if ($filename eq ".") {
	# ignore but do not prune directories
	print "# DEBUG: . ignore #1 $pathname\n" if $opt_v > 4;
    	return;
    }
    if ($filename eq "..") {
	# ignore but do not prune directories
	print "# DEBUG: .. ignore #2 $pathname\n" if $opt_v > 4;
    	return;
    }

    # prune if we have reached the destination directory
    #
    ($nodedev, $nodeino,) = stat($filename);
    if (! defined $nodedev || ! defined $nodedev) {
	# skip stat error
	print STDERR "# $0: Fatal: skipping cannot stat: $filename\n";
	print STDERR "# $0: stat err prune near exit(10): $pathname\n";
	$File::Find::prune = 1;
	exit(10) unless defined $opt_a;
	return;
    }
    if ($destdev == $nodedev && $destino == $nodeino) {
	# destdir prune
	print "# DEBUG: at destdir prune #3: $pathname\n" if $opt_v > 2;
	$File::Find::prune = 1;
	return;
    }

    # if we are cleaning out subdirs, just rmdir directories
    #
    if ($just_rmdir) {
	if ($opt_n) {
	    print "rmdir $pathname\n";
	} else {
	    print "rmdir $pathname\n" if $opt_v > 0;
	    rmdir $pathname if -d $pathname;
	    if (-d $pathname) {
		++$dir_behind;
	    }
	}
	return;
    }

    # determine the destination name
    #
    $name = substr($pathname, length($srcdir)+1);
    print "# DEBUG: name: $name\n" if $opt_v > 4;
    $destpath = "$destdir/$name";
    print "# DEBUG: destpath: $destpath\n" if $opt_v > 3;

    # untaint destination name
    #
    if ($destpath =~ /$untaint/o) {
    	$destpath = $1;
    } else {
	print STDERR "# $0: Fatal: strange chars in destpath \n";
	print STDERR "# $0: tainted destpath prune near exit(11): $destpath\n";
	$File::Find::prune = 1;
	exit(11) unless defined $opt_a;
	return;
    }

    # move if the destination does not exist
    #
    if (! -e $destpath) {
	if ($opt_n) {
	    print "mv $pathname $destpath\n";
	} elsif (move($pathname, $destpath) == 1) {
	    # move prune
	    print "mv $pathname $destpath\n" if $opt_v > 0;
	    $File::Find::prune = 1;
	} else {
	    # move error
	    print STDERR "# $0: Fatal: move error: $!\n";
	    print STDERR "# $0: err near exit(12): mv $pathname $destpath\n";
	    $File::Find::prune = 1;
	    exit(12) unless defined $opt_a;
	}
	return;
    }
    # destination exists

    # If the destination is a directory, continue walking the directory
    #
    if (-d $destpath) {
	# ignore but do not prune destination directory that exists
	print "# DEBUG: dir exist ignore #4: $destpath\n" if $opt_v > 4;
    	return;
    }

    # If -f (force move) then move source on top of destination
    #
    if ($opt_f) {
	if ($opt_n) {
	    print "mv -f $pathname $destpath\n";
	} elsif (move($pathname, $destpath) == 1) {
	    # move force prune
	    print "mv -f $pathname $destpath\n" if $opt_v > 0;
	    $File::Find::prune = 1;
	} else {
	    # move error
	    print STDERR "# $0: Fatal: move error: $!\n";
	    print STDERR "# $0: err near exit(13): mv -f $pathname $destpath\n";
	    $File::Find::prune = 1;
	    exit(13) unless defined $opt_a;
	}
	return;
    }

    # leave the destination behind
    #
    print STDERR "# $0: destination exists: $destpath\n";
    print STDERR "# $0: leaving behind: $pathname\n";
    ++$left_behind;
    return;
}
