#!/bin/bash
# Copyright (C) 2013 Paolo Valente <paolo.valente@unimore.it>
#                    Arianna Avanzini <avanzini.arianna@gmail.com>

../utilities/check_dependencies.sh awk dd fio iostat
if [[ $? -ne 0 ]]; then
	exit
fi

. ../config_params.sh
. ../utilities/lib_utils.sh

sched=$1
NUM_READERS=${2-1}
NUM_WRITERS=${3-0}
RW_TYPE=${4-seq}
STAT_DEST_DIR=${5-.}
DURATION=${6-10}
SYNC=${7-yes}
MAXRATE=${8-0} # If useful with other schedulers than bfq, 16500
		   # is apparently the maximum value for which the
		   # system does not risk to become unresponsive, with
		   # sequential writers, under any scheduler with a 90
		   # MB/s hard disk.

# see the following string for usage, or invoke aggthr_of_greedy_rw.sh -h
usage_msg="\
Usage (as root):\n\
./aggthr-with-greedy_rw.sh [\"\" | bfq | cfq | ...]\n\
                           [num_readers] [num_writers]\n\
                           [seq | rand | raw_seq | raw_rand ]\n\
                           [stat_dest_dir] [duration] [sync]\n\
                           [max_write-kB-per-sec] \n\
\n\
first parameter equal to \"\" -> do not change scheduler\n\
raw_seq/raw_rand -> read directly from device (no writers allowed)\n\
sync parameter equal to yes -> invoke sync before starting readers/writers\n\
\n\
For example:\n\
sudo ./aggthr-with_greedy_rw.sh bfq 10 0 rand ..\n\
switches to bfq and launches 10 rand readers and 10 rand writers\n\
with each reader reading from the same file. The file containing\n\
the computed stats is stored in the .. dir with respect to the cur dir.\n\
\n\
Default parameter values are \"\", $NUM_WRITERS, $NUM_WRITERS, \
$RW_TYPE, $STAT_DEST_DIR, $DURATION, $SYNC and $MAXRATE\n"

if [ "$1" == "-h" ]; then
        printf "$usage_msg"
        exit
fi

mkdir -p $STAT_DEST_DIR
# turn to an absolute path (needed later)
STAT_DEST_DIR=`cd $STAT_DEST_DIR; pwd`

set_scheduler

echo Preliminary sync to wait for the completion of possible previous writes
sync

# create and enter work dir
rm -rf results-${sched}
mkdir -p results-$sched
cd results-$sched

# setup a quick shutdown for Ctrl-C 
trap "shutdwn 'fio iostat'; exit" sigint

init_tracing
set_tracing 1

start_readers_writers_rw_type $NUM_READERS $NUM_WRITERS $RW_TYPE $MAXRATE

echo Flushing caches
if [ "$SYNC" != "yes" ]; then
	echo Not syncing
	echo 3 > /proc/sys/vm/drop_caches
else
	# Flushing in parallel, otherwise sync would block for a very
	# long time
	flush_caches &
fi

if (( $NUM_READERS > 0 || $NUM_WRITERS > 0)); then

	# wait for reader/writer start-up transitory to terminate
	secs=$(transitory_duration 7)

	while [ $secs -ge 0 ]; do
	    echo -ne "Waiting for transitory to terminate: $secs\033[0K\r"
	    sleep 1
	    : $((secs--))
	done
	echo
fi

echo Measurement started, and lasting $DURATION seconds

start_time=$(date +'%s')

# start logging aggthr
iostat -tmd /dev/$DEV 2 | tee iostat.out &

# wait for reader/writer start-up transitory to terminate
secs=$DURATION

while [ $secs -gt 0 ]; do
    echo "Remaining time: $secs"
    if [[ "$SYNC" == "yes" && $NUM_WRITERS -gt 0 ]]; then
	echo Syncing again in parallel ...
	sync &
    fi
    sleep 2
    : $((secs-=2))
done
echo

shutdwn 'fio iostat'

end_time=$(date +'%s')

actual_duration=$(($(date +'%s') - $start_time))

if [ $actual_duration -gt $(($DURATION + 10)) ]; then
    echo Run lasted $actual_duration seconds instead of $DURATION
    echo In this conditions the system, and thus the results, are not reliable
    echo Aborting
    rm -rf results-${sched}
    exit
fi

mkdir -p $STAT_DEST_DIR
file_name=$STAT_DEST_DIR/\
${sched}-${NUM_READERS}r${NUM_WRITERS}\
w-${RW_TYPE}-${DURATION}sec-aggthr_stat.txt
echo "Results for $sched, $NUM_READERS $RW_TYPE readers and \
$NUM_WRITERS $RW_TYPE writers" | tee $file_name
print_save_agg_thr $file_name

cd ..

# rm work dir
rm -rf results-${sched}
