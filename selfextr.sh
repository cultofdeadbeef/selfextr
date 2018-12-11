#!/bin/bash
# Copyright 2018 Cult of Dead Beef <cultofdeadbeef@mail.ru>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# The copyright holder has the right to change the copyright license type in
# future versions of this software. Changes to the license may apply retroactively,
# but can then only affect comercial use.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#	- One cold december night with too much weed.
#						poltergiest
#
# Configure section. Change these settings if you wish. 
OUTFILE="install.sh" # Set default output filename to install.sh
TARFLAGS="xf" # Default archive flags. Only change if you really know what you are doing!
TAR="tar" # Default archive program. Currently only tar is supported.
TESTFILES=0 # Disable archive validity checks. NOT WORKING.
SIGNFILES=1 # Set default gpg sign file off.
ENCRYPTFILES=0 # Encrypt payload with gpg?
VMODE="0" # Set default verbose mode off.
DEBUG="0" # Set debug mode on/off Default off
# End user config.
# Edit below at your own risk.
VERSION="1.1.2"
IS_ROOT=0 # Check if run as root.
useage(){
  # Display program usage.
  echo "selfextr $VERSION"
  echo "Program usage: "
  echo "$0 -i <input tarfile> [-o <output file name>] [-e <gpg key id>]"
}
print_help(){
  useage
  echo ""
  echo "Linux Archive Self Extractor"
  echo "Version $VERSION"
  echo ""
  echo "(c) 2018 Cult of Dead Beef"
  echo "https://github.com/cultofdeadbeef/selfextr.git"
  echo ""
  echo "Help"
  echo "-h		Show this information"
  echo ""
  echo "-i <filename>	Input file name. *REQUIRED*"
  echo "-o <filename>	Output file name."
  echo "-n		Do not create a sign / hash files"
  echo "-v		Verbose mode"
  echo "-e <recipient>	Encrypt payload with gpg."
  echo ""
  echo "Advanced:"
  echo "-H		Include header file"
  echo "-F		Include footer file"
  echo ""
  echo "-A		/path/to/software Change default archive software."
  echo "		Only tar is supported!"
  echo ""
  echo "-f		Override archive software arguments. specify without \"-\""
  echo "		Use at your own risk!"
  echo ""
  echo "Header and footer files are bash compatible scripts that run"
  echo "before and after the payload."
  echo ""
  echo "Example: $0 -i example.tar.gz -H myheader.file -F myfooter.file"
  echo "myheader.file contents:"
  echo "mkdir -p path/to/directory"
  echo "cd path/to/directory"
  echo ""
  echo "myfooter.file contents:"
  echo "sudo \$TMP_DIR/install.sh"
  echo ""
  echo "Will create a self extracting archive that will make a directory"
  echo "and change to it, before it extracts the archive and run sudo \$TMP_DIR/install.sh"
  echo "after it has extracted the archive."
  echo ""
  echo "\$TMP_DIR is a global script variable that is set when -r is used."
  echo ""
}
signfile(){
  # Sign file with gpg
  echo "GPG Sign $SIGNFILENAME"
}
USER_NAME=$(whoami)
if [ $USER_NAME == "root" ] ; then
  IS_ROOT=1
  if [ $VMODE == "1" ] ; then
    echo "Running script as root. WARNING."
  fi
fi
if [ DEBUG == 1 ] ; then echo "DEBUG: USER_NAME=$USER_NAME" ; fi
GPG=$(which gpg) # Location to gpg
if [ DEBUG == 1 ] ; then echo "DEBUG: GPG=$GPG" ; fi
GPG_RECIPIENT=""
INPUTFILE=""
HEADERFILE=""
FOOTERFILE=""
MYYEAR=$(date +"%Y")
if [ DEBUG == 1 ] ; then echo "DEBUG: MYYEAR=$MYYEAR" ; fi
AUTHOR_NAME=$(awk -v user="$USER" -F":" 'user==$1{print $5}' /etc/passwd)
if [ DEBUG == 1 ] ; then echo "DEBUG: AUTHOR_NAME=$AUTHOR_NAME" ; fi
if [ $IS_ROOT == "1" ] ; then
  if [ $VMODE == "1" ] ; then
    echo "Creating tempfiles as nobody since we are root."
  fi
  if [ DEBUG == 1 ] ; then echo "DEBUG: Yikes! running the script as root. Add exploit code to next version. ;)" ; fi
  TEMPFILE=$(su nobody -s /bin/sh -c mktemp)
  PAYLOAD=$(su nobody -s /bin/sh -c mktemp)
  if [ $VMODE == 1 ] ; then 
    echo "Made temp files $TEMPFILE and $PAYLOAD"
  fi
else
  TEMPFILE=$(mktemp)
  PAYLOAD=$(mktemp)
fi
if [ DEBUG == 1 ] ; then echo "DEBUG: TEMPFILE=$TEMPFILE" ; fi
if [ DEBUG == 1 ] ; then echo "DEBUG: PAYLOAD=$PAYLOAD" ; fi
MD5_FILE_SUM=0
MD5_DATA_SUM=0
while getopts 'o:i:t:b:a:s:hnve' OPTION ; do
  case $OPTION in
    o)
      # Output file name
      OUTFILE=${OPTARG}
      ;;
    h)
      # Help
      print_help
      exit 0
      ;;
    i)
      # Input filename (Payload)
      INPUTFILE=${OPTARG}
      ;;
    H)
      # Include header from file
      HEADERFILE=${OPTARG}
      ;;
    F)
      # Include footer from file
      FOOTERFILE=${OPTARG}
      ;;
    A)
      # Change archive software
      TAR=${OPTARG}
      ;;
    f)
      # Override tar flags
      TARFLAGS=${OPTARG}
      ;;
    s)
      # Dont sign files.
      SIGNFILES=1
      ;;
    v)
      # Set verbose mode on
      VMODE=1
      ;;
    r)
      # Set command to run post extraction
      ;;
    e)
      # Enable encryption
      ENCRYPTFILES=1
      GPG_RECIPIENT=${OPTARG}
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    *)
      useage
      ;;
  esac
done
shift "$(($OPTIND -1))"
if [ $VMODE == "1" ] ; then
  echo "Version: $VERSION"
  echo "Input file: $INPUTFILE"
  echo "Output file: $OUTFILE"
  echo "Header file: $HEADERFILE"
  echo "Footer file: $FOOTERFILE"
  echo "Verbose mode: ON"
  echo "Running script as: $USER"
  echo "Payload temp file: $PAYLOAD"
  echo "Script temp file: $TEMPFILE"
fi
# Check if things are sane.
if [ $VMODE == 1 ] ; then
  echo "Checking if things are sane."
fi
if [ -z $INPUTFILE ] ; then
  useage
  rm -f $TEMPFILE $PAYLOAD
  exit 1
fi
if [ $VMODE == 1 ] ; then
  echo "Checking input file."
fi
if [ ! -f $INPUTFILE ] ; then
  echo "Error: Input file <$INPUTFILE> does not exist or is not a regular file."
  rm -f $TEMPFILE $PAYLOAD
  exit 1
fi
# Get the md5 sum of file.
MD5_FILE_SUM=$(md5sum $INPUTFILE)
if [ $VMODE == 1 ] ; then
  echo "Checking if outfile exists."
fi
if [ -e $OUTFILE ] ; then
  echo "Error: Output file <$OUTFILE> exists. Aborting."
  rm -f $PAYLOAD $TEMPFILE
  exit 1
fi
if [ $VMODE == 1 ] ; then
  echo "Checking for tar."
fi
if [ ! -e $TAR ] ; then
  # Tar missing?! Broken host system?
  TARTEMP=$(which $TAR)
  if [ -e $TARTEMP ] ; then
    TAR=$TARTEMP
  else
    echo "Error: tar command is missing."
	rm -f $PAYLOAD $TEMPFILE
    exit 1
  fi
fi
if [ $VMODE == 1 ] ; then
  echo "Checking for gpg since -n is not specified."
fi
if [ SIGNFILE == 1 ] ; then
  if [ -z $GPG ] ; then
    echo "Error: GPG not found. Not signing or encrypting files. Enforcing -n"
    SIGNFILE=0
    ENCRYPTFILE=0
  fi
fi
if [ -z $FOOTERFILE ] ; then
  if [ $VMODE == 1 ] ; then
    echo "Checking for footer file."
  fi
  if [ ! -f $FOOTERFILE ] ; then
    echo "Error: Header file not found. Specified: $FOOTERFILE"
    exit 1
  fi
fi
if [ -z $HEADERFILE ] ; then
  if [ $VMODE == 1 ] ; then
    echo "Checking for header file."
  fi
  if [ ! -f $HEADERFILE ] ; then
    echo "Error: Header file not found. Specified: $HEADERFILE"
    exit 1
  fi
fi
if [ DEBUG == 1 ] ; then echo "ENCRYPTFILES = $ENCRYPTFILES" ; fi #debug
echo "Creating $OUTFILE from source"
if [ VMODE == 1 ] ; then
  echo "Setting up payload."
  if [ $ENCRYPTFILES == 1 ] ; then
    echo "Encrypting files"
  fi
  if [ $ENCRYPTFILES == 0 ] ; then
    echo "Using base64 to encode files."
  fi
fi
if [ $ENCRYPTFILES == 1 ] ; then
  if [ $VMODE == 1 ] ; then
    echo "Encrypting $INPUTFILE to $PAYLOAD"
  fi
    $GPG -e --output $PAYLOAD --armour $INPUTFILE
fi
if [ $ENCRYPTFILES == 0 ] ; then
  if [ $VMODE == 1 ] ; then
    echo "base64 $INPUTFILE > $PAYLOAD"
  fi
  base64 $INPUTFILE > $PAYLOAD
fi
MD5_DATA_SUM=$(cat $PAYLOAD | md5sum)
if [ $VMODE == 1 ] ; then
  echo "Initializing $OUTFILE"
fi
if [ DEBUG == 1 ] ; then echo "DEBUG: TEMPFILE=$TEMPFILE" ; fi
cat > $TEMPFILE <<EOF
#!/bin/sh
# Created with Linux Archive Self Extractor v1.0
# https://github.com/cultofdeadbeef/selfextr.git
#
# Copyright $MYYEAR $USER $AUTHOR_NAME
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software
# and associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial
# portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
# NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
ORIGFILENAME="$INPUTFILE"
TMPFILE=\$(mktemp)
MD5_FILE_SUM="$MD5_FILE_SUM"
MD5_DATA_SUM="$MD5_DATA_SUM"
ENCRYPTED="$ENCRYPTFILE"
EOF
if [ $VMODE == 1 ] ; then
  echo "Adding md5 sum for $INPUTFILE to $OUTFILE"
  echo "Adding md5 sum for payload data to $OUTFILE"
fi
if [ ! -z $HEADERFILE ] ; then
  if [ $VMODE == 1 ] ; then
    echo "Copying header."
  fi
  cat $HEADERFILE >> $TEMPFILE
fi
if [ $VMODE == 1 ] ; then
  echo "Attaching payload"
fi
echo "cat > \$TMPFILE <<EOF" >> $TEMPFILE
cat $PAYLOAD >> $TEMPFILE
echo "EOF" >> $TEMPFILE
echo "MD5_DATA_TMP=\$(cat \$TMPFILE | md5sum)" >> $TEMPFILE
echo "if [ \"\$MD5_DATA_SUM\" != \"\$MD5_DATA_TMP\" ] ; then" >> $TEMPFILE
echo "  echo \"Error: Payload checksum error.\"" >> $TEMPFILE
echo "  rm -f \$TMPFILE" >> $TEMPFILE
echo "  exit 1" >> $TEMPFILE
echo "fi" >> $TEMPFILE
echo "base64 -d \$TMPFILE > \$ORIGFILENAME" >> $TEMPFILE
echo "$TAR $TARFLAGS \$ORIGFILENAME" >> $TEMPFILE
echo "MD5_FILE_TMP=\$(md5sum \$ORIGFILENAME)" >> $TEMPFILE
echo "if [ \"\$MD5_FILE_SUM\" != \"\$MD5_FILE_TMP\" ] ; then" >> $TEMPFILE
echo "  echo \"Error: file checksum error.\"" >> $TEMPFILE
echo "  echo exit 1" >> $TEMPFILE
echo "fi" >> $TEMPFILE
if [ ! -z $FOOTERFILE ] ; then
  if [ $VMODE == 1 ] ; then
    echo "Copying footer."
  fi
  cat $FOOTERFILE >> $TEMPFILE
fi
echo "rm -f \$TMPFILE" >> $TEMPFILE
cp $TEMPFILE $OUTFILE
if [ SIGNFILE == 1 ] ; then
  if [ VMODE == 1 ] ; then
    echo "Signing output file: $OUTPUT"
  fi
  $GPG --sign --armour $OUTFILE
fi
echo "Cleaning up."
if [ VMODE == 1 ] ; then
  echo "Deleting script temp file: $TEMPFILE"
fi
if [ -f $TEMPFILE ] ; then
  rm -f $TEMPFILE
fi
if [ VMODE == 1 ] ; then
  echo "Deleting payload temp file: $PAYLOAD"
fi
if [ -f $PAYLOAD ] ; then
  rm -f $PAYLOAD
fi
chmod 755 $OUTFILE
