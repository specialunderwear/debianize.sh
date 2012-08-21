#! /bin/bash
HELP='
Usage: debianize.sh -m "nobody <nobody@example.com>" -i django -i buildthistoo\n
   -m The maintainer string ("nobody <nobody@example.com>")\n
   -i Using this flag makes following dependencies explicit. It will only\n
      build dependencies listed in install_requires that match the regex\n
      specified after -i. Use -i multiple times to specify multiple packages\n
   -f full path to fpm binary to use.\n
   -p full path to pip binary to use.\n
\n   
\n
All flags are optional\n
Anything after an unknown flag has been encountered, will be passed to fpm as arguments.\n
\n
'

MAINTAINER="somebody@example.com"
FOLLOW_DEPENDENCIES=""
FPM_BIN="fpm"
PIP_BIN="pip"
LAST_OPTION=1

while getopts ":m:i:p:f:" opt; do
  case $opt in
    m)
      MAINTAINER=$OPTARG
      LAST_OPTION=$OPTIND
      ;;
    i)
      if [[ $FOLLOW_DEPENDENCIES == "" ]]; then
          FOLLOW_DEPENDENCIES=$OPTARG
      else
          FOLLOW_DEPENDENCIES="$FOLLOW_DEPENDENCIES|$OPTARG"
      fi
      LAST_OPTION=$OPTIND
      ;;
    f)
      FPM_BIN=$OPTARG
      LAST_OPTION=$OPTIND
      ;;
    p)
      PIP_BIN=$OPTARG
      LAST_OPTION=$OPTIND
      ;;
    \?)
      if [[ $OPTARG =~ \?|h ]]; then
          echo -e $HELP >&2
          exit
      fi
      break
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# remove options from args
shift $(($LAST_OPTION - 1))

if [[ $EUID -ne 0 ]]; then
   echo "You must be root to build a debian package." 1>&2
   exit 100
fi

# remove existing packages
echo "Cleaning old .deb files."
rm -f *.deb

# build package
echo "building package"
$FPM_BIN --maintainer="$MAINTAINER" --exclude=*.pyc --exclude=*.pyo --depends=python --category=python -s python -t deb "$@" setup.py

if [ `which dpkg-deb` ]; then
    # only do this if dpkg-deb is installed.
    PACKAGE_VERSION=`dpkg-deb --info python-*.deb | grep Version | cut -c 11-`
    PACKAGE_NAME=`dpkg-deb --info python-*.deb | grep Package | cut -c 11-`

    if [ -d upstart ]; then
        echo "building extra package in upstart dir"
        cd upstart
        CONFIG_FILES=`find etc -type f | grep -v svn | xargs -i% echo "--config-files=/%"`
        $FPM_BIN $CONFIG_FILES -x ".svn*" -x "**.svn*" -x "**.svn**" --maintainer="$MAINTAINER" --category=misc -s dir -t deb -n "$PACKAGE_NAME.d" -v "$PACKAGE_VERSION" -d "$PACKAGE_NAME (= $PACKAGE_VERSION)" -a all *
        if [ $? -ne 0 ]; then
        	echo "error occured while building upstart-package"
        	exit
        fi 
        mv $PACKAGE_NAME* ..
        cd ..
    fi
fi

echo "-----------------------------------------------------------"
echo "Downloading dependencies."

# download dependencies
HASH=`openssl dgst -sha1 setup.py | cut -c 17-`
PACKAGE_VAULT=/tmp/.$HASH
mkdir -p $PACKAGE_VAULT
$PIP_BIN -q install --upgrade --no-install --build=$PACKAGE_VAULT -e .

echo "processing dependencies."
for NAME in `ls $PACKAGE_VAULT`
do
    echo -n "package $NAME found in dependency chain, "
    if [[ $NAME =~ $FOLLOW_DEPENDENCIES ]]; then
        echo "BUILDING ...."
        $FPM_BIN --maintainer="$MAINTAINER" --exclude=*.pyc --exclude=*.pyo --depends=python --category=python -s python -t deb $PACKAGE_VAULT/$NAME/setup.py
    else
        echo "skipping ...."
    fi
done
echo "-----------------------------------------------------------"

#clean up
rm -fr $PACKAGE_VAULT
