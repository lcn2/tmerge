# tmerge

merge one tree into another


# To install

```sh
make clobber all
sudo make install clobber
```


# To use

```sh
/usr/local/bin/tmerge srcdir destdir
```

```
/usr/local/bin/tmerge [-a] [-f] [-k] [-n] [-h] [-v lvl] [-V] srcdir destdir

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

Version: 1.7.1 2025-03-23
```


# Reporting Security Issues

To report a security issue, please visit "[Reporting Security Issues](https://github.com/lcn2/tmerge/security/policy)".
