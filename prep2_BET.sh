#!/bin/bash

# Create log file
log_file="/data/lisanne/bids/bet_processing_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$log_file") 2>&1

# Configuration
base_dir="/data/lisanne/bids"
bet_threshold=0.35

# Declare associative array for uniqueness
declare -A unique_subjects

# Loop through files to get unique subjects
for filepath in "$base_dir"/sub-*/ses-01/dwi/*; do  
    filename=$(basename "$filepath")
    subj=$(echo "$filename" | grep -oE 'sub-[A-Za-z0-9]+')  # Extract subject ID
    if [[ -n "$subj" ]]; then
        unique_subjects["$subj"]=1
    fi
done

# Print list of unique subjects
for subj in "${!unique_subjects[@]}"; do
    echo "File $subj is present."
done

# Loop through subjects, move to subject dir
for subj in "${!unique_subjects[@]}"; do
  dwi_dir="$base_dir/$subj/ses-01/dwi"
  if [ -d "$dwi_dir" ]; then
    echo "Found directory: $dwi_dir"
    cd "$dwi_dir" || { echo "Failed to change to directory: $dwi_dir"; continue; }

    # Perform BET on topup output
    if [ -f "my_corrected_b0.nii.gz" ]; then
      # Average corrected images:
      fslmaths my_corrected_b0.nii.gz -Tmean AP_b0_mean.nii.gz
      
      # Run BET on the mean image
      bet AP_b0_mean.nii.gz AP_b0_mean_brain_${bet_threshold/./}.nii.gz -f "$bet_threshold" -m
      
      echo "BET completed for $subj with threshold -f $bet_threshold"
    else
      echo "WARNING: my_corrected_b0.nii.gz not found in $dwi_dir"
    fi
  else
    echo "Directory not found: $dwi_dir"
  fi 
done

