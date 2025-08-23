#!/bin/bash

#SBATCH -J v4StP_srl    # Set job name once here
#SBATCH -o %x.%j.out    # %x = job name, %j = job ID
#SBATCH -e %x.%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 48:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# Enable command tracing for the entire script || all commands will be echoed (with variable expansions) into the .err file
set -x

# ========== LOAD NECESSARY MODULES ==========

# necessary modules have been loaded through .bashrc

# ========== USER SETTINGS (edit these per run) ==========

# Mode selector: set to either "test (<=1 month run duration)" or "prod (>=1 year run duration)"
MODE="test"              # options: test | prod

# Values to inject into 'run_dir/data' (in seconds). These will be applied via in-place edits.
END_TIME=864000          # e.g., 10 days = 10*86400s
MONITOR_FREQ=8640
ADJ_MONITOR_FREQ=8640
ADJ_DUMP_FREQ=8640

# ========== PATHS & NAMES ==========

job_name=$SLURM_JOB_NAME # Use the job name set above
base_dir="$SLURM_SUBMIT_DIR"
build_dir="$base_dir/build_tapAdj_serial"

# Convert END_TIME (sec) -> days (string with 2 decimals), and inject into run_dir name
END_TIME_DAYS=$(awk -v s="$END_TIME" 'BEGIN{printf "%.2f", s/86400}')
run_dir="/scratch2/tshahriar/v4_soma_tapAdj_runs/${job_name}_${MODE}_${END_TIME_DAYS}dRun${SLURM_JOB_ID}" # unique per job

# ========== SELECT data_*Run INSIDE input_tap BEFORE STAGING THE run DIRECTORY ==========

pushd "$base_dir/input_tap" >/dev/null
if [[ "$MODE" == "test" ]]; then
  cp -f data_testRun data # -f means overwrite even if target is write-protected.
elif [[ "$MODE" == "prod" ]]; then
  cp -f data_productionRun data
else
  echo "ERROR: MODE must be 'test' or 'prod' (got: $MODE)" >&2
  exit 1
fi
popd >/dev/null

# ========== STAGE run DIRECTORY ==========

mkdir -p "$run_dir"
cd "$run_dir"

cp "$base_dir/input_tap"/* .
ln -s "$base_dir/input_binaries"/* .
ln -s "$base_dir/input_adj_binaries"/* .

# In-place edits (value-only; never touch comments)
# Skip commented lines (first non-space is # or !), and only replace the token after "key ="
sed -Ei '/^[[:space:]]*[#!]/! s/([[:space:]]*endTime[[:space:]]*=[[:space:]]*)[^, ]+/\1'"$END_TIME"'/'           ./data
sed -Ei '/^[[:space:]]*[#!]/! s/([[:space:]]*monitorFreq[[:space:]]*=[[:space:]]*)[^, ]+/\1'"$MONITOR_FREQ"'/'   ./data
sed -Ei '/^[[:space:]]*[#!]/! s/([[:space:]]*adjMonitorFreq[[:space:]]*=[[:space:]]*)[^, ]+/\1'"$ADJ_MONITOR_FREQ"'/' ./data
sed -Ei '/^[[:space:]]*[#!]/! s/([[:space:]]*adjDumpFreq[[:space:]]*=[[:space:]]*)[^, ]+/\1'"$ADJ_DUMP_FREQ"'/'   ./data

# Executable
cp -p "$build_dir/mitgcmuv_tap_adj" .

# ========== RUN & TIMING ==========
run_start_time=$(date +%s)
echo "Run started at: $(date)" > run_timing.txt
echo "Mode: ${MODE}; endTime=${END_TIME}s (${END_TIME_DAYS} days)" >> run_timing.txt

./mitgcmuv_tap_adj > output_tap_adj.txt 2>&1

run_end_time=$(date +%s)
echo "Run ended at:   $(date)" >> run_timing.txt
elapsed=$((run_end_time - run_start_time))
printf "Total runtime:  %02d:%02d:%02d (HH:MM:SS)\n" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60)) >> run_timing.txt
