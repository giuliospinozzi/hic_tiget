#!/bin/bash

#le colonne del file tabulato sono fisse
#non è importante in quale cartella si runna lo script
#a differenza dello script in cui si normalizza ogni sample da solo, qui la logica dello script è un pò diversa.
#inoltre, le cartelle in cui salverà gli output saranno contrassegnati dal suffisso "_NORM"

FILE=$1
RESOLUTION=$2
MAXTHREADS=$3

#salvo il path in cui eseguo lo script perchè in esso è presente anche il file .tsv nei cicli while successivi sarà necessario darglielo
#altrimenti, dato che nel primo while cambiamo cd, non riuscirà più a leggerlo.
#execution_dir=$(pwd)
#-echo "$execution_dir"

#Arrays for Normalization of muliple samples
types_t=()     #array che conterrà i tipi di trattamento dei sample treated (T1, T2, ecc)
num_rows_no_none=0  #inizializzo un contatore che conterà quante sono le righe del file .tsv riguardanti campioni trattamento. e quindi quanti sono i campioni trattamento, qualsiasi sia il trt.
					#questa variabile credo non servi più a nulla. Era un'idea iniziale, non più elaborata. confermarlo con il run dello script con dati reali

#Arrays for HICREP steps
all_samples_names=()   #conterrà i nomi di tutti i samples, sia untreated che treated (ogni tipo di treatment)
project_path=()        #conterrà il path della cartella progetto, quella che contiene tutti samples


treated=()
untreated=()


## 1° CICLO DI LETTURA DEL FILE .TSV ##

### Leggo tutte le righe del file .tsv (una per iterazione). Se il tipo di Treatment non c'è nell array "types_t", lo aggiungo ad esso
### Se il tipo di trattamento è indicato come "None", allora essi sono sample "Untreated", quindi salvo  i loro nomi nell'array "untreated"
### Nello stesso ciclo, converto le matrici dal formato .hic a quello .cool, .h5 ed .mcool, che serviranno successivamente


while IFS=$'\t' read -r sample ID path_dir T_UT T_Type Fastq1_Dir Fastq2_Dir  #salvo ogni valore di ogni colonna in una variabile mentre leggo tutte le righe
do
  arr=($sample $ID $path_dir $T_UT $T_Type $Fastq1_Dir $Fastq2_Dir) #salvo le variabili in un array per comodità
  
 
  mkdir -p ${arr[2]}/${arr[0]}/hicexplorer_results/${RESOLUTION}_resolution
  mkdir -p ${arr[2]}/hicrep_results/${RESOLUTION}_resolution
  
  
  ### DA MODIFICARE: creare la cartella "diff_TADs_analysis" e poi al suo interno una cartella per ogni risoluzione. Mettere l'if per verificare che la main dir 
  ### non esista, altrimenti mi da l'errore che la cartella esiste già
  
  if [ ! -e "${arr[2]}/diff_TADs_analysis_${RESOLUTION}" ]; then
  	mkdir ${arr[2]}/diff_TADs_analysis_${RESOLUTION}
  fi
  
  ####################
  
  #salvo i path piu utijuicer_resultslizzati in variabili, cosi da snellire il codice
  juicer_results_dir=${arr[2]}/${arr[0]}/juicer_results/aligned
  hicexp_outdir=${arr[2]}/${arr[0]}/hicexplorer_results/${RESOLUTION}_resolution
  hicrep_outdir=${arr[2]}/hicrep_results/${RESOLUTION}_resolution
  

  printf "\n Sample ${arr[0]} is TREATED with treatment ${arr[4]} \n"  #colonna "T_Type"
  if [[ ! " ${types_t[*]} " =~ " ${arr[4]} " ]]; then
     types_t+=(${arr[4]})                                    #salvo il nome del tipo ti trattamento nell'apposito array
  fi
     num_rows_no_none=$((num_rows_no_none + 1))              #incrementa il contatore ogni volta che legge una riga di un campione treated


  printf "\n >>>>>>>>> ${arr[0]} --> hicConvertFormat \n"
  hicConvertFormat -m ${juicer_results_dir}/inter_30.hic  --inputFormat hic --outputFormat cool -o ${hicexp_outdir}/inter_30.cool --resolution ${RESOLUTION}
  hicConvertFormat -m ${hicexp_outdir}/inter_30_${RESOLUTION}.cool --inputFormat cool --outputFormat h5 -o ${hicexp_outdir}/inter_30_${RESOLUTION}.h5
  hicConvertFormat -m ${hicexp_outdir}/inter_30_${RESOLUTION}.cool --inputFormat cool --outputFormat mcool -o ${hicexp_outdir}/inter_30_${RESOLUTION}.mcool --resolutions ${RESOLUTION}

done < <(tail -n +2 ${FILE})                                     #fornisco il file da leggere e dico che voglio leggere dalla linea 2 (skippo l'header)

echo "il num di righe non None (e quindi il numero di sample trattati) è: ${num_rows_no_none}"
echo "Samples treatments types are: ${types_t[@]}"



## 2° CICLO DI LETTURA DEL FILE .TSV ##

####Per ogni TIPO DI TRATTAMENTO precedentemente identificato nel .tsv, per ogni riga del .tsv raggruppo nella variabile "sample_names" i nomi dei sample aventi quel tipo di trattamento
####E utilizzo i sample names per generare i comandi di hicNormalize specifici per normalizzare assieme le matrici dei sample treated  aventi lo stesso tipo di trattamento
for t in ${types_t[@]};
do
   echo "Considering treatment $t to indicate the cycle"
   sample_names=()                                                           #conterrà i sample names di sample trattati con uno stesso tipo di trattamento ad ogni iterazione "for t in ${types_t[@]}"
   norm_input_trt=()						             #conterrà i path delle matrici .h5 degli specifici treated samples da normalizzare
   norm_output_trt=()			                       	             #conterrà i path delle matrici output normalizzate " normalized.h5" degli specifici treated samples normalizzati
   while IFS=$'\t' read -r sample ID path_dir T_UT T_Type Fastq1_Dir Fastq2_Dir
   do
      arr=($sample $ID $path_dir $T_UT $T_Type $Fastq1_Dir $Fastq2_Dir)
      
      hicexp_outdir=${arr[2]}/${arr[0]}/hicexplorer_results/${RESOLUTION}_resolution  #lo devo rimettere perchè sennò hicexp_outdir sarà uguale al path dell'ultimo sample analizzato nel primo ciclo while
      
  	  if [[ ${t} = ${arr[4]} ]]; then
    	  sample_names+=(${arr[0]})
          norm_input_trt+=(${hicexp_outdir}/inter_30_${RESOLUTION}.h5)
          norm_output_trt+=(${hicexp_outdir}/inter_30_${RESOLUTION}_normalized.h5)
      fi

      done < <(tail -n +2 ${FILE})

      echo "Treated samples with treatment ${t} are: ${sample_names[@]}"
      echo "Comand to normalize is: ${norm_input_trt[@]}"
      echo "Final command is:  hicNormalize -m ${norm_input_trt[@]} -n smallest -o ${norm_output_trt[@]}"

      printf "\n"
      echo ">>>>>>>>> hicNormalize - normalizing together samples treated with treatment ${t}: ${sample_names[@]} "
      hicNormalize -m $(echo "${norm_input_trt[@]}") -n smallest -o $(echo "${norm_output_trt[@]}")                                




done


## 3° CICLO DI LETTURA DEL FILE .TSV ##

###Post NORMALIZE -> CorrectMatrix, FindTADs, DetectLoops

while IFS=$'\t' read -r sample ID path_dir T_UT T_Type Fastq1_Dir Fastq2_Dir
do
  arr=($sample $ID $path_dir $T_UT $T_Type $Fastq1_Dir $Fastq2_Dir)

  hicexp_outdir=${arr[2]}/${arr[0]}/hicexplorer_results/${RESOLUTION}_resolution

  printf "\n >>>>>>>>> ${arr[0]} --> hicCorrectMatrix \n"
  hicCorrectMatrix diagnostic_plot --matrix ${hicexp_outdir}/inter_30_${RESOLUTION}_normalized.h5 -o   ${hicexp_outdir}/inter_30_${RESOLUTION}_normalized_diagnostic.png
  hicCorrectMatrix correct -m ${hicexp_outdir}/inter_30_${RESOLUTION}_normalized.h5 -o ${hicexp_outdir}/inter_30_${RESOLUTION}_corrected.h5

  printf "\n >>>>>>>>> ${arr[0]} --> hicFindTADs \n"
  hicFindTADs -m ${hicexp_outdir}/inter_30_${RESOLUTION}_corrected.h5 --outPrefix ${hicexp_outdir}/tads_hic_corrected --numberOfProcessors ${MAXTHREADS} --correctForMultipleTesting fdr --maxDepth $((${RESOLUTION}*10)) --thresholdComparison 0.05 --delta 0.01
  printf "\n >>>>>>>>> ${arr[0]} --> hicDetectLoops \n"
  hicDetectLoops -m ${hicexp_outdir}/inter_30_${RESOLUTION}.cool -o ${hicexp_outdir}/loops.bedgraph --maxLoopDistance 2000000 --windowSize 10 --peakWidth 6 --pValuePreselection 0.05 --pValue 0.05 --threads ${MAXTHREADS}

  printf "\n >>>>>>>>>> ${arr[0]} --> make_tracks_file \n"
  make_tracks_file --trackFiles ${hicexp_outdir}/inter_30_${RESOLUTION}_corrected.h5 ${hicexp_outdir}/tads_hic_corrected_boundaries.bed -o ${hicexp_outdir}/tracks.ini 

  #save all sample's name in "all_samples_names" array for hicrep subsequent step
  all_samples_names+=(${arr[0]})

  #save project folder path in "project_path" array for hicrep and hicDifferentialTADs subsequent step
  if [ "${#project_path[@]}" -lt 1 ]; then
     project_path+=(${arr[2]})
  fi


#salviamo i path dei campioni T nell'array "treated" e quelli dei campioni UT nell array "untreated" per l analisi differenziale successiva
   if [[ ${arr[4]} = "T" ]]; then
      echo "Adding sample name "${arr[0]}" to treated array" 
      treated+=(${arr[0]})
   else
      echo "Adding sample name "${arr[0]}" to untreated array"
      untreated+=(${arr[0]})
   fi


done < <(tail -n +2 ${FILE})




echo "Treated samples are: ${treated[@]}"
echo "Untreated samples are: ${untreated[@]}"

# Differential TADs analysis #

  printf "\n >>>>>>>>>> hicDifferentialTAD \n"
  for t_sample in ${treated[@]}; do
     for ut_sample in ${untreated[@]}; do

      hicDifferentialTAD -cm ${project_path[0]}/${ut_sample}/${RESOLUTION}_resolution_NORM/inter_30_${RESOLUTION}_corrected.h5 -tm ${project_path[0]}/${t_sample}/${RESOLUTION}_resolution_NORM/inter_30_${RESOLUTION}_corrected.h5 -td ${project_path[0]}/${t_sample}/${RESOLUTION}_resolution_NORM/tads_hic_corrected_domains.bed -o ${project_path[0]}/diff_TADs_analysis_${RESOLUTION}/differential_tads_${ut_sample}-${t_sample} -p 0.01 -t 4 -mr all --threads ${MAXTHREADS}

      done
  done




### HICREP ###  - usa la matrice .mcool, quindi quest' analisi non differisce in base alla normalizzazione utilizzata, ma differisce in base alla risoluzione
#miglorare questa parte dei parametri in base alla risoluzione: e se ho risoluzioni diverse da 5000 e 10000? E se ne ho più di due? Risolvere


#setup of "h" parameter according to resolution (binSize)
if [[ ${RESOLUTION} = 5000 ]]; then
    echo "With resolution=5000, h=10"
    h=10
elif [[ ${RESOLUTION} = 10000 ]]; then
    echo "With resolution=10000, h=20"
    h=20
fi

#echo "Samples to compare are: ${all_samples_names[@]}"

for sample1 in ${all_samples_names[@]}; do
    for sample2 in ${all_samples_names[@]}; do

    if [[ "${sample1}" != "${sample2}" ]]; then   #evita confronti tra lo stesso campione
    printf "\n ------> Comparison between samples: ${sample1}-${sample2} \n"
    hicrep ${project_path[0]}/${sample1}/hicexplorer_results/${RESOLUTION}_resolution/inter_30_${RESOLUTION}.mcool ${project_path[0]}/${sample2}/hicexplorer_results/${RESOLUTION}_resolution/inter_30_${RESOLUTION}.mcool ${project_path[0]}/hicrep_results/${RESOLUTION}_resolution/hicrep_${sample1}-${sample2}_SCC1.txt  --binSize ${RESOLUTION}  --h ${h} --dBPMax 500000
    fi

   done
        samples=(${all_samples_names[@]:1:100})  #non so specificare diversamente che deve fare un subset dall'elemento 1 all ultimo elemento dell array
done

																																																					    





