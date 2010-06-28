#!/bin/bash

# see the following string for usage, or invoke task_vs_rw.sh -h
usage_msg="\
Usage:\n\
calc_overall_stats.sh test_result_dir [num_quantities]
   \n\
   Where num_quantities is the number of quantities reported in the\n\
   output file generated by each execution of one of the test,scripts.\n\
   \n\
   Use 3 as second parameter for agg_thr-with-greedy_rw.sh,\n\
   and 4 for comm_startup_lat.sh or task_vs_rw.sh\n\
\n\
   For example:\n\
   calc_overall_stats.sh ../results/kons_startup 4\n\
   computes the min, max, avg, std_dev and 99%conf of the avg values\n\
   reported in each of the output files found in the ../results/kons_startup\n\
   dir and in its subdirs.\n\
   \n\
   The default value of num_quantities is 4\n"
   
results_dir=`cd $1; pwd`
num_quants=${2:-3}
record_lines=${3:-$(($num_quants * 3 + 1))}

record_lines=$(($num_quants * 3 + 1))
CALC_AVG_AND_CO=`pwd`/calc_avg_and_co.sh

if [ "$1" == "-h" ]; then
        printf "$usage_msg"
        exit
fi

function quant_loops
{
	for ((cur_quant = 0 ; cur_quant < $num_quants ; cur_quant++)); do
		cat $in_file | awk \
			-v line_to_print=$(($cur_quant * 3 + 1))\
			'{ if (n == line_to_print) {
				print $0
				exit
			   }
			   n++ }' > line_file$cur_quant
		second_field=`cat line_file$cur_quant | awk '{print $2}'`
		if [ "$second_field" == "of" ] || \
			[ "$second_field" == "completion" ] ; then
			cat $in_file | awk \
				-v line_to_print=$(($cur_quant * 3 + 2))\
				'{ if (n == line_to_print) {
					printf "%d\n", $0
					exit
			   	   }	
				   n++ }' >> number_file$cur_quant
		else
			cat $in_file | awk \
				-v line_to_print=$(($cur_quant * 3 + 3))\
				'{ if (n == line_to_print) {
					print $3
					exit
			   	   }	
				   n++ }' >> number_file$cur_quant
		fi
	done
}

function file_loop
{
	n=0
	for in_file in `find $results_dir -name "*$sched*$file_filter"`; do

		if (($n == 0)); then
			head -n 1 $in_file | tee -a ../$out_file
		fi
		n=$(($n + 1))

		quant_loops
	done
	if (($n > 0)); then
		echo $n repetitions | tee -a ../$out_file
	fi
}

out_file=overall_stats-`basename $results_dir`.txt
rm -f $out_file

# create and enter work dir
rm -rf work_dir
mkdir -p work_dir
cd work_dir

for file_filter in "*10*seq*" "*10*rand*" "*5*seq*" "*5*rand*"; do
	for sched in bfq cfq; do
		file_loop
		if [ ! -f line_file0 ]; then
			continue
		fi

		for ((cur_quant = 0 ; cur_quant < $num_quants ; cur_quant++));
		do
			cat line_file$cur_quant | tee -a ../$out_file
			second_field=`tail -n 1 ../$out_file |\
		       		awk '{print $2}'`
			cat number_file$cur_quant |\
				$CALC_AVG_AND_CO 99 |\
				tee -a ../$out_file
			rm line_file$cur_quant number_file$cur_quant
		done
	done
	if (($n > 0)); then
	echo ------------------------------------------------------------------
	fi
done


cd ..
rm -rf work_dir
