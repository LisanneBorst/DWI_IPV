#!/bin/bash

# Set base directory
base_dir="/data/lisanne/bids/"

# Find unique subject IDs
declare -A unique_subjects
for filepath in "$base_dir"/sub-*/ses-01/dwi/*; do
    filename=$(basename "$filepath")
    subj=$(echo "$filename" | grep -oE 'Be.{6}')
    if [[ -n "$subj" ]]; then
        unique_subjects["$subj"]=1
    fi
done

# Loop through each subject
for subj in "${!unique_subjects[@]}"; do
    echo "Processing subject $subj..."
    
    dwi_dir="$base_dir/sub-$subj/ses-01/dwi"
    if [ -d "$dwi_dir" ]; then
        cd "$dwi_dir" || continue

        ###### Rename files ######
        echo "Renaming files in $dwi_dir..."
        mv *B300b_dwi.bvec 300AP.bvec 2>/dev/null
        mv *B300_dwi.bvec 300PA.bvec 2>/dev/null
        mv *B1k_dwi.bvec 1000PA.bvec 2>/dev/null
        mv *B2k_dwi.bvec 2000PA.bvec 2>/dev/null

        mv *B300b_dwi.nii.gz 300AP.nii.gz 2>/dev/null
        mv *B300_dwi.nii.gz 300PA.nii.gz 2>/dev/null
        mv *B1k_dwi.nii.gz 1000PA.nii.gz 2>/dev/null
        mv *B2k_dwi.nii.gz 2000PA.nii.gz 2>/dev/null

        mv *B300b_dwi.bval 300AP.bval 2>/dev/null
        mv *B300_dwi.bval 300PA.bval 2>/dev/null
        mv *B1k_dwi.bval 1000PA.bval 2>/dev/null
        mv *B2k_dwi.bval 2000PA.bval 2>/dev/null

        ###### Concatenate files to form Multishell ######
        if [ ! -f Multishell.nii.gz ]; then
            echo "Merging files into Multishell.nii.gz..."
            fslmerge -t Multishell.nii.gz 300PA.nii.gz 1000PA.nii.gz 2000PA.nii.gz
            paste -d " " 300PA.bval 1000PA.bval 2000PA.bval > bvals
            paste -d " " 300PA.bvec 1000PA.bvec 2000PA.bvec > bvecs
        else
            echo "Multishell.nii.gz already exists. Skipping merge."
        fi
        
        ###### Extract b0 images ######
        if [ ! -f AP_PA_b0.nii.gz ]; then
            fslroi 300AP AP_b0 0 1
            fslroi 300PA PA_b0 0 1
            fslmerge -t AP_PA_b0 AP_b0 PA_b0
        else
            echo "AP_PA_b0.nii.gz already exists. Skipping b0 extraction."
        fi

        ###### Create acqparams.txt ######
        printf "0 1 0 0.0646\n0 -1 0 0.0646" > acqparams.txt
        echo "acqparams.txt created"

        ###### Adjust for even slice number ######
        fslroi AP_PA_b0.nii.gz AP_PA_b0.nii.gz 0 118 0 118 0 82 0 2
        fslroi Multishell.nii.gz Multishell.nii.gz 0 118 0 118 0 82 0 114
        fslroi 1000PA.nii.gz 1000PA.nii.gz 0 118 0 118 0 82 0 38

        ###### Run topup ######
        topup --imain=AP_PA_b0 --datain=acqparams.txt --config=b02b0.cnf --out=my_topup_output --iout=my_corrected_b0

        echo "Subject $subj processing complete."
    else
        echo "Directory not found for subject $subj"
    fi
done

