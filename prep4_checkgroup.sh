#!/bin/bash

# Configuration
base_dir="/data/lisanne/bids"

cd $base_dir

# Run quality control for multishell group
eddy_squad codigos/eddy_qc_Multishell_folders.txt -u -g codigos/eddy_grupos.txt -o quad_group_Multishell

echo "check is performed for the multishell group"

# Run quality control for 1000PA group
eddy_squad codigos/eddy_qc_1000PA_folders.txt -u -g codigos/eddy_grupos.txt -o quad_group_1000PA

echo "check is performed for the 1000PA group"

