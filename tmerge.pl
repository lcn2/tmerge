#!/usr/bin/perl -wT
#
# fmerge - merge one tree into another
#
# @(#) $Revision: 1.22 $
# @(#) $Id: exifrename.pl,v 1.22 2005/07/18 10:01:39 chongo Exp $
# @(#) $Source: /usr/local/src/cmd/exif/RCS/exifrename.pl,v $
#
# Copyright (c) 2005 by Landon Curt Noll.  All Rights Reserved.
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
use vars qw($opt_v $opt_h $opt_a $opt_f $opt_n);
use Getopt::Long;
use File::Find;
no warnings 'File::Find';
use File::Copy;

# version - RCS style *and* usable by MakeMaker
#
my $VERSION = substr q$Revision: 1.1 $, 10;
$VERSION =~ s/\s+$//;

# my vars
#
# NOTE: We will only cd into dirs whose name is only [-+\w\s./] chars
my $untaint = qr|^([-+\w\s./]+)$|; 	# untainting path pattern
my $srcdir;				# what is being moved
my $destdir;			# where files are being moved to
my $destdev;			# device of $destdir
my $destino;			# inode numner of $destdir
my $left_behind = 0;		# files left behind under srcdir

# usage and help
#
my $usage = "$0 [-a] [-f] [-n] [-h] [-v lvl] srcdir destdir";
my $help = qq{$usage

	-a	     don't abort/exit after a fatal error (def: do)
	-f	     force override of existing files (def: don't)
	-n	     do not move anything, just print cmds (def: move)

	-h	     print this help message
	-v 	     verbose / debug level

	srcdir	     source directory from which to merge
	destdir	     destination directory

    NOTE:
	exit 0	all is OK
	exit >0 some fatal error

    Version: $VERSION};
my %optctl = (
    "a" => \$opt_a,
    "f" => \$opt_f,
    "n" => \$opt_n,
    "h" => \$opt_h,
    "v=i" => \$opt_v,
);


# function prototypes
#
sub wanted();


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
	exit(2);
    }
    if (defined $opt_h) {
	# just print help, no error
	print STDERR "# $0: usage: $help\n";
	exit(0);
    }
    if (! defined $ARGV[0] || ! defined $ARGV[1]) {
	print STDERR "# $0: missing args\nusage:\n\t$help\n";
	exit(3);
    }
    if (defined $ARGV[2]) {
	print STDERR "# $0: too many args\nusage:\n\t$help\n";
	exit(4);
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
    if ($opt_v > 1) {
	print "# DEBUG:";
	print " -v $opt_v" if $opt_v > 0;
	print " $srcdir $destdir\n";
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

    # untaint $srcdir, $destdir, and $rollfile
    #
    if ($srcdir =~ /$untaint/o) {
    	$srcdir = $1;
    } else {
	print STDERR "# $0: bogus chars in srcdir\n";
	exit(5);
    }
    if ($destdir =~ /$untaint/o) {
    	$destdir = $1;
    } else {
	print STDERR "# $0: bogus chars in destdir\n";
	exit(6);
    }

    # record the device and inode number of $destdir
    #
    ($destdev, $destino,) = stat($destdir);
    if (! defined $destdev || ! defined $destdev) {
	print STDERR "# $0: destdir not found\n";
	exit(7);
    }

    # walk the srcdir, making renamed copies and symlinks
    #
    find(\%find_opt, $srcdir);
    if ($left_behind > 0) {
	print STDERR "# $0: left $left_behind file(s) behind under $srcdir\n";
	exit(1);
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
#	$adding_readme		0 ==> function being called by find()
#				!= 0  ==> function being called by add_readme()
#
sub wanted($)
{
    my $filename = $_;		# current filename within $File::Find::dir or
				# absolute path of readme if $adding_readme!=0
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
	print STDERR "# $0: tainted destpath prune #8 $pathname\n";
	$File::Find::prune = 1;
	exit(8) unless defined $opt_a;
	return;
    }

    # ignore names that match common directories
    #
    if ($filename eq ".") {
	# ignore but do not prune directories
	print "# DEBUG: . ignore #9 $pathname\n" if $opt_v > 4;
    	return;
    }
    if ($filename eq "..") {
	# ignore but do not prune directories
	print "# DEBUG: .. ignore #10 $pathname\n" if $opt_v > 4;
    	return;
    }

    # prune if we have reached the destination directory
    #
    ($nodedev, $nodeino,) = stat($filename);
    if (! defined $nodedev || ! defined $nodedev) {
	# skip stat error
	print STDERR "# $0: Fatal: skipping cannot stat: $filename\n";
	print STDERR "# $0: stat err prune #11: $pathname\n";
	$File::Find::prune = 1;
	exit(11) unless defined $opt_a;
	return;
    }
    if ($destdev == $nodedev && $destino == $nodeino) {
	# destdir prune
	print "# DEBUG: at destdir prune #12: $pathname\n" if $opt_v > 2;
	$File::Find::prune = 1;
	return;
    }

    # determinme the destination name
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
	print STDERR "# $0: tainted destpath prune #13 $destpath\n";
	$File::Find::prune = 1;
	exit(13) unless defined $opt_a;
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
	    print STDERR "# $0: err #14: mv $pathname $destpath\n";
	    $File::Find::prune = 1;
	    exit(14) unless defined $opt_a;
	}
	return;
    }
    # destination exists

    # If the destination is a directory, continue walking the directory
    #
    if (-d $destpath) {
	# ignore but do not prune destination directory that exists
	print "# DEBUG: dir exist ignore #15: $destpath\n" if $opt_v > 4;
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
	    print STDERR "# $0: err #16: mv -f $pathname $destpath\n";
	    $File::Find::prune = 1;
	    exit(16) unless defined $opt_a;
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
