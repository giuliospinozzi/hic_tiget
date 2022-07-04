#!/bin/bash

#HIC PIPELINE (script che eseguirà juicer, tadbit, hicexplorer ecc)


#scriptsDir (-D): la directory contenente gli SCRIPT di juicer (/opt/applications/scripts/juicer)
#topDir (-d): la directory che conterrà gli output prodotti con juicer (lo script crea "juicer_out" e la rendo cwd. cwd è topDir di default)

#site_file (option -y): il file con i restriction enzyimes sites. Devo averne uno nella apposita dir "restriction_sites" nella juice_


### NEW ### Introducing OPTARG instead of constant input from command line

# Activate Anaconda Environment (HiC)
#conda activate hic

##Read arguments
usageHelp="Usage: ${0##*/} [-a assoc_file] [-D scriptsDir] [-g genomeID] \n [-z genome_fa]  [-m genome_gem] [-s site] \n [-r tadbit_resolution] [-R hicexplorer_resolution] [-t threads] [-h help]"
scriptsDirHelp="* [scriptsDir] is the absolute path of the directory containing the main script, which must be present in the same directory of "scripts" directory, in which must be hicexplorer_hicrep_TIGET.sh, tadbit_TIGET.sh, juicer_TIGET.sh and the "common" directory containing all the scripts called by juicer"
genomeHelp="* [genomeID] e.g. \"hg19\" or \"mm10\" \n [genome_fa] is the absolute path of the .fa file of the reference genome. This file should be present in the same directory with the .fa index files. \n [genome_gem] is the absolute path to the .gem file of the reference genome"
siteHelp="* [restriction enzyme]: enter the name of the restriction enzyme" 
tadbitResolutionHelp="* [tadbit_resolution] is the resolution that will be utilized by tadbit to make plots"
hicexplorerResolutionHelp="* [hicexplorer_resolution] could be a single value or a list of value divided by a comma. hicexplorer will be executed for each sample, for each indicated resolution"
threadsHelp="* [threads]: number of threads when running tadbit full_mapping, juicer BWA alignment, hicexplorer hicFindTADs, hicDetectLoops, hicDifferentialTAD "
helpHelp="* -h: print this help and exit"


printHelpAndExit() {
    echo -e "$usageHelp"
    echo -e "$scriptsDirHelp"
    echo -e "$genomeHelp"  #(description of genomeID, genome_fa e genome_gem)
    echo -e "$siteHelp"
	echo -e "$tadbitResolutionHelp"
	echo -e "$hicexplorerResolutionHelp"
    echo -e "$threadsHelp"
    echo "$helpHelp"
    exit "$1"
     #echo -e "$stageHelp"
   #echo -e "$pathHelp"       (al momento inutile, perchè diamo il genomeID tramite cui retriva i chrom.sizes)
}


while getopts "a:D:g:z:m:s:p:r:R:t:l:h:" opt; do
    case $opt in
	a) assoc_file=$OPTARG ;;   #file di associazione (.tsv)
	D) scriptsDir=$OPTARG ;;	   #path alla directory contenente gli script di juicer (script.sh e dir common DEVONO essere nella stessa directory)	(ex juiceDir)
	g) genomeID=$OPTARG ;;		#es: hg19 (option -g juicer)	
	z) genome_fa=$OPTARG ;;	#path al file .fa del genoma di riferimento (option -z juicer) (/opt/genome/human/hg19/index/hg19.fa)	 
	m) genome_gem=$OPTARG ;;     #abs_path ref genome .gem (/opt/genome/human/hg19/index/gem/hg19.gem)
	s) site=$OPTARG ;;     #Restriction enzyme (es: DpnII)
	p) genomePath=$OPTARG ;; #path to the chrom.size file
	r) tadbit_resolution=$OPTARG ;;  #tadbit resolution at the moment (17.03.2022) is 1000000    
	R) hicexplorer_resolution=$OPTARG ;;
	t) threads=$OPTARG ;;       #num of threads (option -t juicer)
	l) is_shallow=$OPTARG ;;    #true or false. se true, allora tadbit verrà eseguito per intero. Se false, verrà eseguito solo il quality plot. Questo perchè è molto oneroso sui fastq enormi. Se non true e non false, raise error
	h) printHelpAndExit 0;;
	
	[?]) printHelpAndExit 1;;
    esac
done


#----------


while IFS=$'\t' read -r sample ID path_dir T_UT T_Type fastq1 fastq2  #salvo ogni valore di ogni colonna in una variabile mentre leggo tutte le righe
do
  arr=($sample $ID $path_dir $T_UT $T_Type $fastq1 $fastq2) #salvo le variabili in un array per comodità
  
  echo -e "--- Analyzing sample ${arr[0]}\n"
  mkdir ${arr[2]}/${arr[0]} #creo la dir del sample 
  mkdir ${arr[2]}/${arr[0]}/tadbit_results #creo la dir con gli output di tadbit per il sample in analisi
  
  #ASSEMBLY-STATS
  echo -e "--- Assembly-stats on R1 & R2 of sample ${arr[0]}\n"
  assembly-stats <(zcat ${fastq1}) &
  assembly-stats <(zcat ${fastq2}) &
  wait

  
  #TADBIT 
  echo -e "--- TADBIT\n"
  #spiegazione: python3 tadbit_finale1.py sample_name abs_path_R1 abs_path_R2 abs_path_tadbit_results tadbit_resolution abs_path_ref_genome.gem abs_path_ref_genome.fa threads true/false
  python3 ${scriptsDir}/tadbit.py ${arr[0]} ${fastq1} ${fastq2} ${arr[2]}/${arr[0]}/tadbit_results ${tadbit_resolution} ${genome_gem} ${genome_fa} ${threads} ${is_shallow}
   
																												    
  #JUICER
  echo -e "--- JUICER ${arr[0]}\n"
  mkdir ${arr[2]}/${arr[0]}/juicer_results #creo la dir dove salverò gli output di juicer, specifica di un sample
  mkdir ${arr[2]}/${arr[0]}/straw_results
  cd ${arr[2]}/${arr[0]}/juicer_results #cd alla main dir di un sample (ovvero alla directory dove salverò gli output). importante perchè "topDir" in juicer.sh di default è la cwd. Quindi topDir sarà questa directory (e varierà ad ogni iterazione, per ogni sample) 

  # -d è topDir, la directory in cui finiranno gli output. Non la specifico perchè di default è la cwd, specificata prima. -n = sample name
  bash ${scriptsDir}/juicer.sh -D ${scriptsDir} -g ${genomeID} -p ${genomePath} -z ${genome_fa} -n ${arr[0]} -s ${site} -u ${fastq1} -v ${fastq2} -t ${threads} 

  

done < <(tail -n +2 ${assoc_file}) #fornisco il file da leggere e dico che voglio leggere dalla linea 2 (skippo l'header)
  
#HICEXPLORER & HICREP - devo runnarlo al di fuori del loop precedente perchè questo script è fatto per funzionare da solo, al suo interno si looppa a sua volta, quindi
#non ha senso loopare uno script che loopa tra samples. Creerei due loop uno dentro l'altro, che in questo caso è un errore.
echo -e "--- STRAW, HICEXPLORER & HICREP\n"

#eseguo hicexplorer (inclusa analisi tad differenziali) ed hicrep una volta per ogni risoluzione desiderata. Ad es, risoluzione 5000, 10000 ecc.
res_arr=() 
IFS=',' read -r -a res_arr <<< "${hicexplorer_resolution}" 
echo "Resolutions choosed are: ${res_arr[@]}" 
 
arr_len="${#res_arr[@]}"  #lunghezza dell array 1 (che è uguale a quella dell'array 2 di solito) 
for (( i=0; i<=${arr_len}-1; i++ ))    #faccio -1 perchè arr_len è il numero di elementi dell'array, ma gli indici iniziano da 0, quindi devo sottrarre 1 al num totale di elementi 
do
echo -e "--- Executing hicexplorer with resolution ${res_arr[i]}"
bash ${scriptsDir}/hicexplorer_hicrep.sh ${assoc_file} ${res_arr[i]} ${threads}

#STRAW - eseguito per ogni risoluzione indicata nel vettore "hicexplorer_resolution"
echo -e "--- STRAW\n"
mkdir -p ${arr[2]}/${arr[0]}/straw_results/${res_arr[i]}
python3 ${scriptsDir}/straw.py ${arr[2]}/${arr[0]}/juicer_results/aligned/inter_30.hic ${res_arr[i]} ${arr[2]}/${arr[0]}/straw_results

done








### V4 ###
#prova di esecuzione - introduzione delle optarg, input dei files utilizzando una lettera
#./HIC_PIPE_V4.sh -a /home/alessio/hic/complete_hic_pipe_exe/association_file2.tsv -j /home/alessio/hic/complete_hic_pipe_exe -i hg19 -f /opt/genome/human/hg19/index/hg19.fa -s /home/alessio/hic/complete_hic_pipe_exe/restriction_sites/hg19_DpnII.txt -t 16 -r 1000000 -g /opt/genome/human/hg19/index/gem/hg19.gem -R 1000000,500000 -l false



### V3 ###
#prova di esecuzione
#./HIC_PIPE_V3.sh /home/alessio/hic/complete_hic_pipe_exe/association_file2.tsv /home/alessio/hic/complete_hic_pipe_exe hg19 /opt/genome/human/hg19/index/hg19.fa /home/alessio/hic/complete_hic_pipe_exe/restriction_sites/hg19_DpnII.txt 12 1000000 /opt/genome/human/hg19/index/gem/hg19.gem 1000000,500000

#--------------

### V2 ###

#prova di esecuzione
#./HIC_PIPE_V2.sh /home/alessio/hic/complete_hic_pipe_exe/association_file2.tsv /home/alessio/hic/complete_hic_pipe_exe hg19 /opt/genome/human/hg19/index/hg19.fa /home/alessio/hic/complete_hic_pipe_exe/restriction_sites/hg19_DpnII.txt 12 1000000 /opt/genome/human/hg19/index/gem/hg19.gem


#--------------
#V1

#comando tipo per juicer originale
#./juicer.sh -z /opt/genome/human/hg19/index/hg19.fa -p hg19 -D /home/alessio/hic/juicer_prova


#comando runnando juicer_CPU_MOD_OK senza lo script bash superiore
#./juicer_CPU_MOD.sh -D /opt/applications/scripts/juicer -z /opt/genome/human/hg19/index/hg19.fa -p hg19 -t 8 -n 2_1_S1_L001 -u /home/alessio/hic/juicer_prova/fastq/2_1_S1_L001_R1_001.fastq.gz -v /home/alessio/hic/juicer_prova/fastq/2_1_S1_L001_R2_001.fastq.gz


#comando di esempio con cui runnare questo script.
#./HIC_PIPE_V1.sh /home/alessio/hic/juicer_prova/juicer_AF.tsv /home/alessio/hic/juicer_prova hg19 /opt/genome/human/hg19/index/hg19.fa /home/alessio/hic/juicer_prova/restriction_sites/hg19_DpnII.txt 12




