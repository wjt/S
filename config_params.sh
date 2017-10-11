if [[ "$(id -u)" -ne "0" ]]; then
    echo "You are currently executing me as $(whoami),"
    echo "but I need root privileges (e.g., to switch among schedulers)."
    echo "Please run me as root."
    exit 1
fi

# If equal to 1, tracing is enabled during each test
TRACE=0

# The device on which you are about to run the tests, by default tries to peek
# the device used for /
# If it does not work or is not want you want, change it to fit your needs,
# for example:
# DEV=sda
DEV=$(basename `mount | grep "on / " | cut -f 1 -d " "` | sed 's/\(...\).*/\1/g')

# Size of the files to create for reading/writing, in MB.
# For random I/O with rotational devices, consider that the
# size of the files may heavily influence throughput and, in
# general, service properties
FILE_SIZE_MB=500

# portion, in 1M blocks, to read for each file, used only in fairness.sh;
# make sure it is not larger than $FILE_SIZE_MB
NUM_BLOCKS=2000

# where files are read from or written to
BASE_DIR=/var/lib/S
if test ! -d $BASE_DIR ; then
    mkdir $BASE_DIR
fi
if test ! -w $BASE_DIR ; then
    echo "$BASE_DIR is not writeable, reverting to /tmp/test"
    BASE_DIR=/tmp/test
fi

# file names
BASE_FILE_PATH=$BASE_DIR/largefile

# The kernel-development benchmarks expect a repository in the
# following directory. In particular, they play with v4.0, v4.1 and
# v4.2, so they expect these versions to be present.
KERN_DIR=$BASE_DIR/linux.git-for_kern_dev_benchmarks
# If no repository is found in the above directory, then a repository
# is cloned therein. The source URL is stored in the following
# variable.
KERN_REMOTE=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

# NCQ queue depth, if undefined then no script will change the current value
NCQ_QUEUE_DEPTH=

# Mail-report parameters. A mail transfer agent (such as msmtp) and a mail
# client (such as mailx) must be installed to be able to send mail reports.
# The sender e-mail address will be the one configured as default in the
# mail client itself.
MAIL_REPORTS=0
MAIL_REPORTS_RECIPIENT=
