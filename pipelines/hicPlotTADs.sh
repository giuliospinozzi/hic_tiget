#!/bin/bash

### HIC PLOT TADS ###

#Estratto dello script2 in cui plotto soltanto i TADs. Usare quando serve fare soltanto questo step. 
#Input necessari: tracks.ini (e quindi la matrice .corrected.h5 e tads_hic_corrected_domains.bed)
#questo script prevede che il file track.ini si trovi nella stessa cartella di .corrected.h5 e domains.bed

#Da usare con matrici normalizzate assieme, quindi in questo script le cartelle di input e di output hanno il suffisso "_NORM"
#Si usa quando effettivamente bisogna plottare delle regioni, non come era impostato nello script2 originario, nel quale era uno step opzionale e veniva eseguito solo se c'erano delle regioni da plottare
#nella nuova visione della pipeline hic, un master script richiamerà questo sotto-script solo se ci sono regioni da plottare. Se no, non viene chiamato e si passa allo script successivo, che potrebbe essere hicrep o altri


FILE=$1
RESOLUTION=$2
MAXTHREADS=$3
COORDINATES=$4  #coordinate delle regioni da plottare


arr_coor=()
IFS=',' read -r -a arr_coor <<< "${COORDINATES}" 
echo "l'array contenente le coordinate è:  ${arr_coor[@]}" 

#arr_coor_len="${#arr_coor[@]}"

execution_dir=$(pwd)
echo "$execution_dir"


printf "\n>>>>>>>>>> ${arr[0]} --> hicPlotTADs \n"
for coor in ${arr_coor[@]}
do
	echo "la coordinata da plottare è:" ${coor}

        while IFS=$'\t' read -r sample ID path_dir matrix_name T_UT T_Type
	do
	  arr=(${sample} ${ID} ${path_dir} ${matrix_name} ${T_UT} ${T_Type} } )
	  printf "\n #### PROCESSING SAMPLE ${arr[0]} #### \n"
	  cd ${arr[2]}
	  mkdir plotTADs_${RESOLUTION}_${coor}
	  cd ${arr[0]}/${RESOLUTION}_resolution_NORM    #da modificare se modificherò il track.ini inserendo i path assoluti alla matrice corrected.h5 e al domains.bed (automaticamente tramite lo script1)
	  echo "la working directory è:"
	  pwd
	  while IFS=":" read -r chr start_end; do
		while IFS="-" read -r start end; do

		       hicPlotTADs --tracks track.ini -o ../../plotTADs_${RESOLUTION}_${coor}/${arr[0]}_${RESOLUTION}_TADs_${chr}_${start}-${end}.png --region ${coor} --dpi 300

		done <<< ${start_end}
	  done <<< ${coor}

        done < <(tail -n +2 ${FILE})

cd ${execution_dir}
echo "la current directory è:"
pwd

done

