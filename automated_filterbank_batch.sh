#!/bin/bash
#SBATCH --account=
#SBATCH --export=NONE
#SBATCH --time=30:00:00
#SBATCH --mem=8GB
#SBATCH --cpus-per-task=1
#SBATCH --job-name=automated_filterbank
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#1 is number of splits
#2 is DM
#3 is filterbank file
#4 is the location of the scripts
#if we are not splitting then just set out as the fil file
while getopts d:a:p: flag
do
    case "${flag}" in
        d) DM=${OPTARG};;
        a) AFP=${OPTARG};;
        p) p=${OPTARG};;
    esac
done

#path to automated filterbank file script locations
#this is set when you run a batch script by default
#load the module needed
# check that the filterbank file exists this prevents accidental deletion of files with the later rm command
#********************THIS IS THE LAZY WAY OUT!!!
PULSAR=$(echo "$p" | rev | cut -f2- -d '.' | rev)
SLURM_TMPDIR='/home/adam/scratch/tmpdir/'$PULSAR
mkdir -p $SLURM_TMPDIR
SLURM_JOB_ID=1
#make sure that $p is a file
if test -f "$p"; then
    #rename it FIL
    FIL=$p
    cp -d $FIL ${SLURM_TMPDIR}
    echo $FIL
    if [ ! -d ${SLURM_TMPDIR} ]; then
        mkdir ${SLURM_TMPDIR}
    fi
    n=0
    #basically try catch
    until [ "$n" -ge 1 ]
    do
        # DEAD_GPU=$(get_bad_channel_list.py --fmt presto --type filterbank $FIL)
        echo "Running python pipeline"
        python $AFP/gwg_cand_search_pipeline.py --dm $DM --speg --fetch --rfifind --dedisp --sp --fil $FIL --slurm "${SLURM_TMPDIR}" && break
        #FETCH and SPEGID are slow so lets like ignore that for now
        #python $AFP/gwg_cand_search_pipeline.py --dm $DM --rfifind --dedisp --sp --fil $FIL --slurm "${SLURM_TMPDIR}" && break
        #for rapid tests, only do rfifind
        # python $AFP/gwg_cand_search_pipeline.py --dm $DM --rfifind --fil $FIL --slurm "${SLURM_TMPDIR}" && break
        # Should never get here. if it does exit with an error
        exit 1
        n=$((n+1))
        # sleep 15
        #if it fails, lets copy all the things to my scratch directory then exit with error code
        # PULSAR=$(echo "$FIL" | cut -f 1 -d '.')
        #ERRORS=~/"scratch/errors/${PULSAR}_${SLURM_JOB_ID}"
        #echo "copying error files to ${ERRORS}"
        #df -h
        #mkdir -p $ERRORS
        #   cp -r -d ${SLURM_TMPDIR}/* $ERRORS
        #exit 1
        #remove the extra fil files
    done
    PULSAR=$(echo "$FIL" | cut -f 1 -d '.')
    rm "${SLURM_TMPDIR}"/$FIL
    #remove the .dat files
    rm "${SLURM_TMPDIR}"/*.dat
    #tarball the infs and singlepulse files
    tar cf "${SLURM_TMPDIR}/${PULSAR}_singlepulse.tar" "${SLURM_TMPDIR}/"*.singlepulse
    tar cf "${SLURM_TMPDIR}/${PULSAR}_inf.tar" "${SLURM_TMPDIR}/"*DM*.inf
    rm "${SLURM_TMPDIR}"/*DM*.inf
    rm "${SLURM_TMPDIR}"/*DM*.singlepulse
    cp -r ${SLURM_TMPDIR}/* .
    #clean up - not needed on compute canada, but nice to run clean up when on my own computer
    rm -r ${SLURM_TMPDIR}
    exit 0
fi
#didn't find file, throw error
echo "filterbank file not found"
exit 1
