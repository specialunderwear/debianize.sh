Debianize, create debian packages from python packages
======================================================

Debianize uses fpm (https://github.com/jordansissel/fpm) to create debian packages from python source directories. The only thing it really adds, is that debianize will also create packages for all depencencies that your source package has (install_requires). Debianize will only create a debian package from a python package. So you need a setup.py.

Usage
-----

::

	debianize.sh -m "nobody <nobody@example.com>" -i django -i buildthistoo

Accepted flags
--------------

::

   -m The maintainer string ("nobody <nobody@example.com>") (If different as defined in setup.py)
   -i Using this flag makes following dependencies explicit. It will only
      build dependencies listed in install_requires that match the regex
      specified after -i. Use -i multiple times to specify multiple packages
   -I Use this flag to ignore a dependencies from being built. Packages that
      match the regex specified after -I. Use -I multiple times add more ignore
      regexes.
   -f full path to fpm binary to use.
   -p full path to pip binary to use.

All flags are optional.
Anything after an unknown flag has been encountered, *will be passed to fpm as arguments*.
-i and -I are mutually exclusive.

Upstart
-------

If you've got a folder named ``upstart`` next to your setup.py, this folder
will be packaged as well, with the same version number as your package, but
adding a ``.d`` postfix to your package name.
