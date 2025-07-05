#!/bin/bash

base_dir="/data/lisanne/bids/"

# Create log dir/file
log_dir="$base_dir/logs"
mkdir -p "$log_dir"
timestamp=$(date '+%Y%m%d_%H%M%S')
log_file="$log_dir/dti_batch_${timestamp}.log"
exec > >(tee -a "$log_file") 2>&1


printf "\n========= Batch started %s =========\n" "$(date '+%Y-%m-%d %H:%M:%S')"

# Declare associative array for uniqueness
declare -A unique_subjects

# Loop through files and extract unique subjects
for filepath in "$base_dir"/sub-*/ses-01/dwi/*; do
    filename=$(basename "$filepath")
    subj=$(echo "$filename" | grep -oE 'sub-[A-Za-z0-9]+')
    if [[ -n "$subj" ]]; then
        unique_subjects["$subj"]=1
        echo "Selected $subj DTI fitting & maps" 
    fi
done

# Run for each subject
for subj in "${!unique_subjects[@]}"; do
    dwi_dir="$base_dir/$subj/ses-01/dwi"

    if [[ ! -d $dwi_dir ]]; then
        echo "Directory not found: $dwi_dir"; continue
    fi
    echo -e "\n>>> Processing $subj"
    cd "$dwi_dir"

        # For 1000PA
	dtifit -k 1000PA_eddy.nii.gz -o DTI_1000PA -m AP_b0_mean_brain_035_mask -r 1000PA.bvec -b 1000PA.bval --sse
        
        # For Multishell
	dtifit -k Multishell_eddy.nii.gz -o DTI_Multishell -m AP_b0_mean_brain_035_mask -r bvecs -b bvals --sse

	# Create AD and RD maps for 1000PA
	cp DTI_1000PA_L1.nii.gz DTI_1000PA_AD.nii.gz
	fslmaths DTI_1000PA_L2.nii.gz -add DTI_1000PA_L3.nii.gz -div 2 DTI_1000PA_RD.nii.gz
	
	# Create AD and RD maps for Multishell 
	cp DTI_Multishell_L1.nii.gz DTI_Multishell_AD.nii.gz
	fslmaths DTI_Multishell_L2.nii.gz -add DTI_Multishell_L3.nii.gz -div 2 DTI_Multishell_RD.nii.gz

	echo ">>> Finished DTI fitting and  prep for $subj"
done

printf "\n========= Batch finished %s =========\n" "$(date '+%Y-%m-%d %H:%M:%S')"
echo "Logs saved to: $log_file"
