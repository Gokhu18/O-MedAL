#!/usr/bin/env bash

# Run MedAL on Bridges (Pittsburgh Super Computer) by tunneling through a jump
# server.

# To use this script, you should add the following to your ssh config.
# Useful assuming you have a jump host (ie AWS or Google cloud server) from
# which you wish to run the jobs.
#
# Host socksjump
#   Hostname IP_ADDRESS_OF_YOUR_JUMP_HOST
#   User YOUR_USERNAME
#

set -u
set -x

bridges_user=${1}
mode=${2:-donothing}  # interactive|nobridges|some/filepath.sbatch  # if interactive, limited to 8 hours.


# cd into parent directory of the script is
cd "$(dirname "$(dirname "$(readlink -f "$0")")")"
pwd

# rsync latest code over
rsync -ave ssh --exclude __pycache__ --exclude ./data --exclude ./new/data \
  ./ $bridges_user@data.bridges.psc.edu:/pylon5/ci4s8dp/$bridges_user/medal_improvements

if [ "${mode}" = "interactive" ] ; then
# # set up to run interactively on bridges (via a socks proxy running tmux)
# # within bridges, load the gpu interactively and run code inside a tmux session
# # (so can consult nvidia-smi or do other things on the machine while it runs)
TERM=screen ssh -tt -A jump 'tmux new-session -A -s 0 \; new-window -t 0:. -n MedAL -a ssh  '"$bridges_user"'@bridges.psc.edu' <<EOF
module load AI/anaconda3-5.1.0_gpu.2018-08 
source activate \$AI_ENV
cd \$SCRATCH/medal_improvements
source ./data/.bridges_env/bin/activate
pwd

# rm Model_save.hdf5
interact -p GPU-small --gres=gpu:p100:2 -t 00:10:00 -N 1 -n 28
# tmux new-session "python Script.py 2>&1 | tee -a data/log/`date +%Y%m%dT%H%M%S`.log"
tmux new-session "python -m medal 2>&1 | tee -a data/log/`date +%Y%m%dT%H%M%S`.log"
exit
EOF

elif [ -e "$mode" ] ; then # run via sbatch
  echo Sbatch file should exist locally and remotely. Running it:
  echo $mode

ssh $bridges_user@bridges.psc.edu <<EOF
cd \$SCRATCH/medal_improvements/data/log
fp="$(basename "$mode")-`date +%Y%m%dT%H%M%S`.log"
sbatch -o \$fp -e \$fp ../../$mode
EOF

else
  echo Do nothing further
fi
