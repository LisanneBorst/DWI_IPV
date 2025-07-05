#!/bin/bash
#set -euo pipefail # to stop if an error comes up
base_dir="/data/lisanne/bids"

printf "\n========= Batch started %s =========\n" "$(date '+%Y-%m-%d %H:%M:%S')"

# Declare associative array for uniqueness
declare -A unique_subjects

# Loop through files and extract unique subjects
for filepath in "$base_dir"/sub-*/ses-01/dwi/*; do
    filename=$(basename "$filepath")
    subj=$(echo "$filename" | grep -oE 'sub-[A-Za-z0-9]+')
    if [[ -n "$subj" ]]; then
        unique_subjects["$subj"]=1
        echo "Selected $subj for Eddy prep" 
    fi
done

# Run Eddy for each subject
for subj in "${!unique_subjects[@]}"; do
    dwi_dir="$base_dir/$subj/ses-01/dwi"

    if [[ ! -d $dwi_dir ]]; then
        echo "Directory not found: $dwi_dir"; continue
    fi
    echo -e "\n>>> Processing $subj"
    cd "$dwi_dir"

        # Create index for 1000PA
        num_vols_1000=38
        indx_1000=$(yes 2 | head -n "$num_vols_1000" | tr '\n' ' ')
        echo "$indx_1000" > index_1000PA.txt

        # Create index for Multishell 
        num_vols_multi=114
        indx_multi=$(yes 2 | head -n "$num_vols_multi" | tr '\n' ' ')
        echo "$indx_multi" > index_Multishell.txt

        # Eddy for 1000PA 
        eddy --imain=1000PA.nii.gz --mask=AP_b0_mean_brain_035_mask.nii.gz --bvecs=1000PA.bvec --bvals=1000PA.bval --out=1000PA_eddy --topup=my_topup_output --index=index_1000PA.txt --acqp=acqparams.txt --repol --cnr_maps -v > 1000PA_eddy_stdout.log 2> 1000PA_eddy_stderr.log
        echo "Eddy 1000PA has been performed for $subj"
        
        # Eddy for Multishell
        eddy --imain=Multishell.nii.gz --mask=AP_b0_mean_brain_035_mask.nii.gz --bvecs=bvecs --bvals=bvals --out=Multishell_eddy --topup=my_topup_output --index=index_Multishell.txt --acqp=acqparams.txt --data_is_shelled --repol --cnr_maps -v > Multishell_eddy_stdout.log 2> Multishell_eddy_stderr.log
        echo "Eddy Multishell has been performed for $subj"

	# Back-up the original b-vec/b-val files
	cp -n 1000PA.bvec  original_1000PA.bvec   2>/dev/null || true
	cp -n bvecs        original_bvecs         2>/dev/null || true

	# Replace the b-vectors with the rotated versions
	cp 1000PA_eddy.eddy_rotated_bvecs 1000PA.bvec
	cp Multishell_eddy.eddy_rotated_bvecs bvecs

	# Eddy QC (eddy_quad) 
	echo "Running eddy_quad 1000PA QC for $subj"
	eddy_quad 1000PA_eddy     -idx index_1000PA.txt   -par acqparams.txt \
		 -m AP_b0_mean_brain_035_mask.nii.gz      -b 1000PA.bval
	echo "Running eddy_quad Multishell QC for $subj"
	eddy_quad Multishell_eddy -idx index_Multishell.txt -par acqparams.txt \
		 -m AP_b0_mean_brain_035_mask.nii.gz      -b bvals

	echo ">>> Finished eddy prep for $subj"
done

printf "\n========= Batch finished %s =========\n" "$(date '+%Y-%m-%d %H:%M:%S')"

