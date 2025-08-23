#!/bin/bash

#SBATCH -J v4StP_srl_test    # Set job name once here
#SBATCH -o %x.%j.out         # %x = job name, %j = job ID
#SBATCH -e %x.%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 48:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# Enable command tracing for the entire script — all commands (with expansions)
# will be echoed into the .err file for debugging.
set -x

# ========= USER SWITCHES (edit these per run) =================================

# Mode selector: set to either "test" or "production"
MODE="test"        # options: test | production

# Values to inject into 'data' (seconds). These will be applied via in-place edits.
END_TIME=864000          # e.g., 10 days = 10*86400
MONITOR_FREQ=86400
ADJ_MONITOR_FREQ=86400
ADJ_DUMP_FREQ=86400

# ========= Paths & names =======================================================

job_name=$SLURM_JOB_NAME
base_dir="$SLURM_SUBMIT_DIR"
build_dir="$base_dir/build_tapAdj_serial"

# Convert END_TIME (sec) -> days (string with 2 decimals), and inject into run_dir name
END_TIME_DAYS=$(awk -v s="$END_TIME" 'BEGIN{printf "%.2f", s/86400}')
run_dir="/scratch2/tshahriar/v4_soma_tapAdj_runs/${job_name}_d${END_TIME_DAYS}days_run${SLURM_JOB_ID}"

# ========= Stage run directory =================================================

mkdir -p "$run_dir"
cd "$run_dir"

# Copy & link inputs
cp "$base_dir/input_tap"/* .
ln -s "$base_dir/input_binaries"/* .
ln -s "$base_dir/input_adj_binaries"/* .

# Select the correct 'data' for MODE by replacing the local ./data
if [[ "$MODE" == "test" ]]; then
  cp -f "$base_dir/input_tap/data_testRun" ./data
elif [[ "$MODE" == "production" ]]; then
  cp -f "$base_dir/input_tap/data_productionRun" ./data
else
  echo "ERROR: MODE must be 'test' or 'production' (got: $MODE)" >&2
  exit 1
fi

# Inject parameter overrides into ./data (in-place edits).
# These patterns replace the value on lines that define each key, preserving commas/trailing content.
# They assume each key appears on its own line (as is typical in MITgcm namelists).
sed -i -E "s/^[[:space:]]*endTime[[:space:]]*=[[:space:]]*[^,]+/ endTime = ${END_TIME}/" ./data
sed -i -E "s/^[[:space:]]*monitorFreq[[:space:]]*=[[:space:]]*[^,]+/ monitorFreq = ${MONITOR_FREQ}/" ./data
sed -i -E "s/^[[:space:]]*adjMonitorFreq[[:space:]]*=[[:space:]]*[^,]+/ adjMonitorFreq = ${ADJ_MONITOR_FREQ}/" ./data
sed -i -E "s/^[[:space:]]*adjDumpFreq[[:space:]]*=[[:space:]]*[^,]+/ adjDumpFreq = ${ADJ_DUMP_FREQ}/" ./data

# Copy the MITgcm executable (self-contained run directory)
cp -p "$build_dir/mitgcmuv_tap_adj" .

# ========= Timing & run ========================================================

start_time=$(date +%s)
echo "Run started at: $(date)" > run_timing.txt
echo "Mode: ${MODE}; endTime=${END_TIME}s (${END_TIME_DAYS} days)" >> run_timing.txt

# Serial run; all program stdout/stderr captured to a log
./mitgcmuv_tap_adj > output_tap_adj.txt 2>&1

end_time=$(date +%s)
echo "Run ended at:   $(date)" >> run_timing.txt

elapsed=$((end_time - start_time))
printf "Total runtime:  %02d:%02d:%02d (HH:MM:SS)\n" \
  $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60)) >> run_timing.txt
