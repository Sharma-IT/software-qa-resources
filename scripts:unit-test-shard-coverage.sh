#!/usr/bin/env bash

# Set the exit code for the script
set -e

# Function to display help text
function show_help {
  echo "Usage: $0 [-h|--help] [--input-dir INPUT_DIR] [--output-dir OUTPUT_DIR] [--config CONFIG_FILE] [--log LOG_FILE]"
  echo "Options:"
  echo "  -h, --help                 Display this help message."
  echo "  --input-dir INPUT_DIR      Specify the input directory containing coverage reports. Default: ./builds/"
  echo "  --output-dir OUTPUT_DIR    Specify the output directory for coverage reports. Default: ./builds/"
  echo "  --config CONFIG_FILE       Specify the config file for thresholds. Default: ./coverage-config.sh"
  echo "  --log LOG_FILE             Specify the log file. Default: ./coverage-log.txt"
  exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help) show_help ;;
    --input-dir) input_dir="$2"; shift ;;
    --output-dir) output_dir="$2"; shift ;;
    --config) config_file="$2"; shift ;;
    --log) log_file="$2"; shift ;;
    *) echo "Unknown parameter: $1"; show_help ;;
  esac
  shift
done

# Set default values if not provided
input_dir="${input_dir:-./builds/}"
output_dir="${output_dir:-./builds/}"
config_file="${config_file:-./coverage-config.sh}"
log_file="${log_file:-./coverage-log.txt}"

# Validate input and output directories
if [[ ! -d "$input_dir" || ! -d "$output_dir" ]]; then
  echo "Error: Input or output directory does not exist."
  exit 1
fi

# Validate config file
if [[ ! -f "$config_file" ]]; then
  echo "Error: Config file not found."
  exit 1
fi

# Validate log file
if ! touch "$log_file" &> /dev/null; then
  echo "Error: Unable to write to log file."
  exit 1
fi

# Load thresholds from config file
source "$config_file"

# Check if required tools are installed
if ! command -v nyc &> /dev/null; then
  echo "Error: nyc could not be found, please install it."
  exit 1
fi

# Log start time
echo "$(date '+%Y-%m-%d %H:%M:%S') - Script started" >> "$log_file"

# Merge sharded reports
echo "$(date '+%Y-%m-%d %H:%M:%S') - Merging reports..." >> "$log_file"
if nyc merge "$input_dir" "$output_dir/coverage-$(date '+%Y%m%d%H%M%S').json" >> "$log_file" 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Reports merged successfully." >> "$log_file"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to merge reports." >> "$log_file"
  exit 1
fi

# Print out detailed coverage percentages
echo "Coverage Summary:"
nyc report --reporter=text-lcov --temp-dir "$output_dir" | grep -E 'lines|functions|branches|statements' | awk '{print $1, $4}' | sed 's/:/ coverage:/'

# Check threshold is met
echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking coverage thresholds..." >> "$log_file"
nyc check-coverage --temp-dir "$output_dir" \
  --lines "${lines_threshold:-100}" \
  --functions "${functions_threshold:-100}" \
  --branches "${branches_threshold:-100}" \
  --statements "${statements_threshold:-100}" >> "$log_file" 2>&1

# Check if all thresholds passed
if [[ $? -eq 0 ]]; then
  echo "All coverage thresholds passed."
fi

# Log end time
echo "$(date '+%Y-%m-%d %H:%M:%S') - Script completed" >> "$log_file"
