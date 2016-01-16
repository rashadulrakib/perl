#!/usr/bin/perl
use Switch;
use Cwd;
use List::Util qw[min max];

################load settings-delivered###############
open (INSETTING, "<settings.txt") ||     ##  settsings file
        die "Can't open settings.txt $!";
my $setingLine="";
my %settings=();

while ($setingLine=<INSETTING>)    
{
	$setingLine =~ s/^\s+|\s+$//g;
	if(length($setingLine)<=1){
		next;
	}
	
	my @tArr = split('=',$setingLine);
	$settings{@tArr[0]}=@tArr[1];
}	
close INSETTING;

if(scalar(keys %settings)!=6){
	print "Settings.txt must have 6 lines..\n";
	exit;
}

##############################################

my $ngRootDir=$settings{"googleNgramRootDir"};  #"/home/administrator/rakib/google-n-gram/";
my $conceptFilePath=$settings{"conceptFile"};  #"/home/administrator/rakib/WikiPedia/concepts";
my $ocrInputFile=$settings{"inputFile"};
my $ocrOutputFile=$settings{"outputFile"};
my $domainLexicon=$settings{"domainSpecificLexicon"};
my $engDictionaryDir = $settings{"engDictionaryDir"};
$domainLexicon=~ s/^\s+|\s+$//g;
my $onlyCorrectedError="ocrOnlyCorrectedError.txt";

my $WLRootDir=$ngRootDir."1gms/";
my $ngIndexed=$ngRootDir."n-gram-indexed/";

my %subDirs = (
        WL => 40
);

my %hash_unigram=();
my %hash_concept=();
my %hash_dictionary=();

my @all_words=();
my $LOffset = 3;
my $minConceptLength=4;
my $uniPrefix="uni-";
my $freqThe=19401194714;
my @contextGrams = (5);

open(INPUT,"<$ocrInputFile") ||     ##  input file
        die "Can't input $ocrInputFile $!";
		
open OUTPUT, ">", $ocrOutputFile;
open OUTPUTONLYERROR, ">$onlyCorrectedError";
		
######################################################################

loadUniGrams();
loadDictionary();
laodConcepts();
generateWords();
detectCorrectError();

#####################################################
sub loadDictionary{
	print "Loading engDictionary files...\n";
	for(my $i=1; $i<=29;$i++){
		my $unifileName=$engDictionaryDir.$uniPrefix.$i;
		if(-e $unifileName){
			open(UNIFILE,"<$unifileName");
			my $uniG;
			while ($uniG=<UNIFILE>)    
			{
				$uniG =~ s/^\s+|\s+$//g;
				$uniG =~ s/[^a-zA-Z]//g;
				$uniG = lc($uniG);
				if(length($uniG)>=2){
					$hash_dictionary{$uniG}=1;
				}
			}
			close(UNIFILE);
		}
	}
	
	if(length($domainLexicon)>=1){
		open(DOMAININPUT,"<$domainLexicon") ||     ##  domainLexicon file
        die "Can't input $domainLexicon $!";
		my $uniG;
		while ($uniG=<DOMAININPUT>)    
		{
			$uniG =~ s/^\s+|\s+$//g;
			$uniG =~ s/[^a-zA-Z]//g;
			$uniG = lc($uniG);
			if(length($uniG)>=2){
				$hash_dictionary{$uniG}=1;
			}
		}
		close (DOMAININPUT);
	}
	
	print "Loading done.\n";
}

#########################################################################
sub loadUniGrams{
	print "Loading unigram files...\n";
	for my $subDir ( keys %subDirs ) {
		my $maxWL = $subDirs{$subDir};
		for(my $i=1; $i<=$maxWL;$i++){
			my $unifileName = $WLRootDir.$subDir."/".$uniPrefix.$i;
			if(-e $unifileName){
				open(UNIFILE,"<$unifileName");
				my $uniG;
				while ($uniG=<UNIFILE>)    
				{
					my @str=FindToken($uniG);
					$hash_unigram{@str[0]}=@str[1];
				}
				close(UNIFILE);
			}
		}
	}
	print "Loading done.\n";
}

###########################################################################
sub laodConcepts{
	print "Loading concept files...\n";
	open(UNIFILE,"<$conceptFilePath");
	my $concept;
	while ($concept=<UNIFILE>)    
	{
		$concept =~ s/^\s+|\s+$//g;
		$concept =~ s/[^a-zA-Z]//g;
		$concept = lc($concept);
		if(length($concept)>=2){
			$hash_concept{$concept}=1;
		}
	}
	close(UNIFILE);
	
	if(length($domainLexicon)>=1){
		open(DOMAININPUT,"<$domainLexicon") ||     ##  domainLexicon file
        die "Can't input $domainLexicon $!";
		my $uniG;
		while ($uniG=<DOMAININPUT>)    
		{
			$uniG =~ s/^\s+|\s+$//g;
			$uniG =~ s/[^a-zA-Z]//g;
			$uniG = lc($uniG);
			if(length($uniG)>=2){
				$hash_concept{$uniG}=1;
			}
		}
		close (DOMAININPUT);
	}
	
	print "Loading done.\n";
}
############################################################################
sub generateWords{
	my $prevLine="";
	my $main_string;
	while ($main_string=<INPUT>)    
	{
		$main_string =~ s/^\s+|\s+$//g;

		if(length($main_string)>=1){
			if(length($prevLine)>=1){
				my $lastChar = substr $prevLine, (length($prevLine)-1), 1;
				if($lastChar=~ /-/){
					$prevLine=(substr $prevLine, 0, length($prevLine)).$main_string;			
				}else{
					$prevLine=$prevLine." ".$main_string;				
				}
			}else{
				$prevLine=$main_string;
			}
		}else{
			$prevLine =~ s/^\s+|\s+$//g;
			if(length($prevLine)>=1){
				extractWords($prevLine);
			}
			$prevLine="";
		}
	}

	$prevLine =~ s/^\s+|\s+$//g;
	if(length($prevLine)>=1){
		extractWords($prevLine);
	}
	
	print "Total words:".($#all_words +1)."\n";
	
	close(INPUT);
}

########################################################################
sub extractWords{
	my($prevLine)=($_[0]);

	my @tempWords=split (/\s+/,$prevLine);

	foreach my $word (@tempWords){
		my @split_words=split(/—/,$word);
		for my $sword (@split_words){
			$sword=~ s/[\W]+$//g;
			if(length($sword)>0){
				push (@all_words, $sword);
			}
		}
	}
}

##########################################################################################################
sub detectCorrectError{

	for(my $i=0;$i<=$#all_words;$i++)
	{
		$word=@all_words[$i];
		$word=~ s/[\W]+$//g;
		
		if(length($word)<=1){
			next;
		}
		
		if(($i+1)%25==0){
			print OUTPUT "\n";
		}
		
		if(isRomanNubmber($word)){
			#print $word."\n";
			print OUTPUT $word." ";
			next;
		}
		
		if(isAnySpecialToken($word)){
			#print $word."\n";
			print OUTPUT $word." ";
			next;
		}
		
		my $isError=0;
		
		my @tokens = split(/-/,$word);
		
		if($#tokens>=1){
			my $combinedCorrect=1;
			for my $temp (@tokens){
				if((exists $hash_unigram{$temp} and ValidUniGram($temp,$hash_unigram{$temp})==1) or (exists $hash_concept{lc($temp)} and length($temp)>=$minConceptLength)){
					$combinedCorrect=$combinedCorrect*1;
				}else{
					$combinedCorrect=$combinedCorrect*0;
				}
			}
			
			if($combinedCorrect==0){
				my $temp=$word;
				$temp=~ s/-//g;
				if((exists $hash_unigram{$temp} and ValidUniGram($temp,$hash_unigram{$temp})==1) or (exists $hash_concept{lc($temp)} and length($temp)>=$minConceptLength)){
					#print $word."\n";
					print OUTPUT $word." ";
				}else{
					$isError=1;				
				}
			}
			
		}else{
			my $temp = @tokens[0];
			
			if(length($temp)<=1){
				next;
			}
			
			if($temp=~ /[0-9]/){
				#print $word."\n";
				print OUTPUT $word." ";
				next;
			}
		
			if($temp=~ /^[a-zA-Z]+'s$/){	
				my @arr=split(/'/,$temp);
				$temp=@arr[0];
				if((exists $hash_unigram{$temp} and ValidUniGram($temp,$hash_unigram{$temp})==1) or (exists $hash_concept{lc($temp)} and length($temp)>=$minConceptLength)){
					#print $word."\n";
					print OUTPUT $word." ";
					next;
				}else{
					$isError=1;
				}
			}else{
				if((exists $hash_unigram{$temp} and ValidUniGram($temp,$hash_unigram{$temp})==1) or (exists $hash_concept{lc($temp)} and length($temp)>=$minConceptLength)){
					#print $word."\n";
					print OUTPUT $word." ";
					next;
				}else{
					$isError=1;
				}
			}
		}
		
		if($isError==1){
			####### erroneous word
			
			print "Correcting->".$word."; word no=".($i+1)." out of ".($#all_words+1)."\n";
						
			my @candidates=lexicalCorrection($word);
			if($#candidates<0){
				#print $word."\n";
				print OUTPUT $word." ";
				next;
			}
			
			if(scalar(@candidates)>=2 && (lc(@candidates[0]) eq lc(@candidates[1]))){
				print OUTPUTONLYERROR $word."->".@candidates[0]."\n";
				print OUTPUT @candidates[0]." ";
				print "Corrected=".@candidates[0]."\n";
				next;
			}
			
			my %hashContext = ();
			my $lastContextSize=0;
			my $isRelux=0;
			for my $contextSize (@contextGrams){
				
				my $ngFolder = $ngIndexed.getNgramFolder($contextSize);
				my $freqGreaterThanZero = 0;
				$lastContextSize=$contextSize;
				%hashContext =();
				for my $cand (@candidates){
					my @contexts = generateContexts ($cand,$i,$contextSize);
					my $freqSum = getContextsFreqSum(\@contexts,$ngFolder,$contextSize);
					$hashContext{$cand}=$freqSum;
					$freqGreaterThanZero=$freqGreaterThanZero+$freqSum;
				}
				if($freqGreaterThanZero>0){
					last;
				}else{
					$freqGreaterThanZero = 0;
					%hashContext =();
					$isRelux=1;
					for my $cand (@candidates){
						my @contexts = generateReluxContexts ($cand,$i,$contextSize);
						my $freqSum = getReluxContextsFreqSum(\@contexts,$contextSize);
						$hashContext{$cand}=$freqSum;
						$freqGreaterThanZero=$freqGreaterThanZero+$freqSum;
					}
					if($freqGreaterThanZero>0){
						last;
					}
				}
			}
			
			my @sortedKeys = sort { $hashContext{$b} <=> $hashContext{$a} } keys %hashContext;
				
			my $totalContextCandidates = scalar(@sortedKeys);
			if($totalContextCandidates>=1){
				if(lc(@sortedKeys[0]) eq lc(@candidates[0])){
					
					print OUTPUTONLYERROR $word."->".@sortedKeys[0]."\n";
					print OUTPUT @sortedKeys[0]." ";
					print "Corrected=".@sortedKeys[0]."\n";
				}else{
					
					my $sumContextFreq=0;
					for my $kkey (@sortedKeys){
						$sumContextFreq=$sumContextFreq+$hashContext{$kkey};
					}
					my $avgContextFreq = $sumContextFreq/$totalContextCandidates;
					
					if($sumContextFreq==0){ ##no context found for any candidate
						
						print OUTPUTONLYERROR $word."->".@candidates[0]."\n";
						print OUTPUT @candidates[0]." ";
						print "Corrected=".@candidates[0]."\n";
					}else{
						my $countNonZero =0;
						for my $kkey (@sortedKeys){
							if($hashContext{$kkey}>0){
								$countNonZero++;
							}
						}
						if($countNonZero==1){
							
							print OUTPUTONLYERROR $word."->".@sortedKeys[0]."\n";
							print OUTPUT @sortedKeys[0]." ";
							print "Corrected=".@sortedKeys[0]."\n";
						}else{
							my @contextCandidates =();
							for my $kkey (@sortedKeys){
								if($hashContext{$kkey}>=$avgContextFreq){
									push @contextCandidates, $kkey;
								}
							}
							
							my $foundCand=""; 						
							for my $cand (@candidates){
								for my $contxCand (@contextCandidates){
									if(lc($cand) eq lc($contxCand)){
										$foundCand=$cand;
										last;
									}
								}
								if(length($foundCand)>0){
									last;
								}
							}
							if(length($foundCand)>0){
								
								print OUTPUTONLYERROR $word."->".$foundCand."\n";
								print OUTPUT $foundCand." ";
								print "Corrected=".$foundCand."\n";
							}else{
								
								print OUTPUTONLYERROR $word."->".@candidates[0]."\n";
								print OUTPUT @candidates[0]." ";
								print "Corrected=".@candidates[0]."\n";
							}
						}
					}
				}
			}else{ ##no context found for any candidate
				print OUTPUTONLYERROR $word."->".@candidates[0]."\n";
				print OUTPUT @candidates[0]." ";
				
				print "Corrected=".@candidates[0]."\n";
			}
		}else{
			#print $word."\n";
			print OUTPUT $word." ";
		}
	}
	
	close OUTPUT;
	close OUTPUTONLYERROR;
}

################################################

sub getNgramRelaxFolder{
	my($ngSize)=($_[0]);

	switch ($ngSize)
	{
		case 5{
			return "5gm-0-2/";
		}
		case 4{
			return "4gm-0-2/";
		}case 3{
			return "3gm-0/";
		}
	}
	
	return "";
}

##########################################################

sub getNgramFolder{
	my($ngSize)=($_[0]);

	switch ($ngSize)
	{
		case 5{
			return "5gm-0-1/";
		}
		case 4{
			return "4gm-0-1/";
		}case 3{
			return "3gm-0/";
		}
	}
	
	return "";
}

sub generateContexts{
	my($cand, $wordIndex, $contextSize)=($_[0],$_[1],$_[2]);
	
	my @contexts = ();
	
	for(my $position=1;$position<$contextSize;$position++){
		my $context="";
		my $initIndex=$wordIndex - $position;
		for(my $k=$initIndex; $k<$initIndex+$contextSize;$k++){
			if($k==$wordIndex){
				$context = $context." ".$cand;
			}else{
				$context = $context." ".@all_words[$k];
			}
		}
		$context=~ s/^\s+|\s+$//g;
		push(@contexts,$context);
	}
		
	return @contexts;
}

############################################################
sub generateReluxContexts{
	my($cand, $wordIndex, $contextSize)=($_[0],$_[1],$_[2]);
	
	my @contexts = ();
	
	for(my $position=1;$position<$contextSize;$position++){
		my $context="";
		my $initIndex=$wordIndex - $position;
				
		for(my $startReluxPos=$initIndex+1;$startReluxPos<$initIndex+$contextSize;$startReluxPos++){
			if($startReluxPos==$wordIndex){
				next;
			}
			
			$context=@all_words[$initIndex];
			for(my $k=$initIndex+1; $k<$initIndex+$contextSize;$k++){
				if($k==$wordIndex){
					$context = $context." ".$cand;
				}elsif($k==$startReluxPos){
					$context = $context." .*";
				}else{
					$context = $context." ".@all_words[$k];
				}
			}
			$context=~ s/^\s+|\s+$//g;
			push(@contexts,$context);
		}
	}
	
	return @contexts;

}
###########################################################

sub getContextsFreqSum{
	my @contexts =  @{$_[0]};
	my ($ngFolder,$contextSize) = ($_[1],$_[2]);
	
	my @ngIndexForDir = getNgIndexes($contextSize); # (0,1); #####based on context size
	my $maxChars = maxCharsFromANGInDir($contextSize);
	my @fileSuffixes = getFileSuffixes($contextSize);
	
	my $sum =0;
	for my $context (@contexts){
		
		my @ngs = split(/ /,lc($context));
		my $subDir = getSubDir(\@ngs,\@ngIndexForDir,$maxChars);
		my $dir = $ngFolder.$subDir;
		my $fileName = $subDir;
		$fileName=~ s/\///g; 
		
		if( -d $dir){
			for my $suffix (@fileSuffixes){
				my $filePath = $dir.$fileName.$suffix;
				if(-e $filePath){
					$sum = $sum + getCountFromFiles($filePath,$context);
				}
			}
		}
		
	}
	return $sum;
}
###########################################################
sub getReluxContextsFreqSum{
	my @contexts =  @{$_[0]};
	my ($contextSize) = ($_[1]);
	
	my $maxChars = maxCharsFromANGInDir($contextSize);
	my @fileSuffixes = getFileSuffixes($contextSize);
	
	my $sum =0;
	for my $context (@contexts){
		
		my $ngFolder="";
		my @ngIndexForDir=();
		my @tempWords=split (/\s/,$context);
		
		if(@tempWords[1] eq ".*"){
			$ngFolder = $ngIndexed.getNgramRelaxFolder($contextSize);
			@ngIndexForDir = getReluxNgIndexes($contextSize); # (0,2); #####based on context size
		}else{
			$ngFolder = $ngIndexed.getNgramFolder($contextSize);
			@ngIndexForDir = getNgIndexes($contextSize); # (0,1); #####based on context size
		}
		
		my @ngs = split(/ /,lc($context));
		my $subDir = getSubDir(\@ngs,\@ngIndexForDir,$maxChars);
		my $dir = $ngFolder.$subDir;
		my $fileName = $subDir;
		$fileName=~ s/\///g; 
		
		if( -d $dir){
			for my $suffix (@fileSuffixes){
				my $filePath = $dir.$fileName.$suffix;
				if(-e $filePath){
					$sum = $sum + getCountFromFiles($filePath,$context);
				}
			}
		}
	}
	return $sum;
}

###################################################
sub maxCharsFromANGInDir{
	my($ngSize)=($_[0]);

	switch ($ngSize)
	{
		case 5{
			return 2;
		}case 4{
			return 2;
		}case 3{
			return 4;
		}
	}
	
	return 0;

}

###################################################

sub getNgIndexes{
	my($ngSize)=($_[0]);
	
	my @arr=();

	switch ($ngSize)
	{
		case 5{
			push(@arr,0);
			push(@arr,1);
		}
		case 4{
			push(@arr,0);
			push(@arr,1);
		}case 3{
			push(@arr,0);
		}
	}
		
	return @arr;
}

#################################

sub getReluxNgIndexes{
	my($ngSize)=($_[0]);
	
	my @arr=();

	switch ($ngSize)
	{
		case 5{
			push(@arr,0);
			push(@arr,2);
		}
		case 4{
			push(@arr,0);
			push(@arr,2);
		}case 3{
			push(@arr,0);
		}
	}
		
	return @arr;
}

####################################################

sub getSubDir{
	my @ngs =  @{$_[0]};
	my @ngIndexForDir = @{$_[1]};
	my ($maxChars)=($_[2]); 
	my $subDir="";
	
	for my $index (@ngIndexForDir){
		my $ng = @ngs[$index];
		my $minLength = min(length($ng),$maxChars); 
		my @charr = split(//,$ng);
		for(my $k=0;$k<$minLength;$k++){
			$subDir=$subDir.@charr[$k]."/";		
		}
	}
	
	return $subDir;
}

#######################################################
sub getFileSuffixes{
	my($ngSize)=($_[0]);
	my @suffixes = ();
	
	switch ($ngSize)
	{
		case 5{
			push(@suffixes,"-12345");
		}
		case 4{
			push(@suffixes,"-1234");
		}case 3{
			push(@suffixes,"-123");
		}
	}
	
	return @suffixes;
}

#############################################################
sub getCountFromFiles{
	my($ngFile,$reluxContext)=($_[0],$_[1]);
	$reluxContext=~ s/[^a-zA-Z\.\*\s]//g;
	
	my $c=0;
	
	open(NGF,"<$ngFile");
	my $ng;
	while ($ng=<NGF>)    
	{
		$ng =~ s/^\s+|\s+$//g;
		my $lastSpace = rindex($ng,'	');
		my $ngContext= substr($ng,0,$lastSpace);
		my $freq=substr($ng,$lastSpace+1);
		
		if($ngContext=~ /^$reluxContext$/){
			$c=$c+$freq;
		}
	}
	close(NGF);
	
	return $c;
}
############################################################

sub FindToken 
{	
	my($str)=@_;
	my(@token);
	my $idi=0;
    while ($str=~/\S+/g)
	{
		my $tok=$&;
		@token[$idi]=$tok;
		$idi++;
	}
 	return @token;
}
##########################################################################################################

sub ValidUniGram
{
	my($word,$count)=($_[0],$_[1]);
	my $len= length($word); 
		switch ($len)
		{
		case 1		{ if ($count<1000000000){ 
						return 0;}
				
				}
		case 2		{ if ($count<10000000){ 
						return 0;}
				
				}
		case 3		{ if ($count<1000000){ 
						return 0;}
				
				}
		case 4		{ if ($count<100000){ 
						return 0;}
				
				}
		case 5		{ if ($count<100000){ 
						return 0;}
				
				}
		case 6		{ if ($count<10000){ 
						return 0;}
				
				}
		case 7		{ if ($count<10000){ 
						return 0;}
				
				}
		case [8..10]		{ if ($count<10000){ 
						return 0;}
				
				}
		case [11..15]		{ if ($count<1000){ 
						return 0;}
				
				}
		case [16..100]		{ if ($count<200){ 
						return 0;}
				
				}
		}
	return 1;
}
###################################################

sub isRomanNubmber{
	my($num)=lc($_[0]);
	
	switch ($num)
	{
		case "i"{
			return 1;
		}case "ii"{
			return 1;
		}case "iii"{
			return 1;
		}case "iv"{
			return 1;
		}case "v"{
			return 1;
		}case "vi"{
			return 1;
		}case "vii"{
			return 1;
		}case "viii"{
			return 1;
		}case "ix"{
			return 1;
		}case "x"{
			return 1;
		}case "xi"{
			return 1;
		}case "xii"{
			return 1;
		}case "xiii"{
			return 1;
		}case "xiv"{
			return 1;
		}case "xv"{
			return 1;
		}case "xvi"{
			return 1;
		}case "xvii"{
			return 1;
		}case "xviii"{
			return 1;
		}case "xix"{
			return 1;
		}
	}
	
	return 0;	
}

#################################################
sub isAnySpecialToken{
	my($token)=lc($_[0]);
	
	switch ($token)
	{
		case "pp"{
			return 1;
		}
	}
	
	return 0;	
}

##########################correction module###########
sub lexicalCorrection{
	
	my @candidates = ();
	my($eWord)=($_[0]);
	$eWord=~ s/[^a-zA-Z]//g;
	my $lenEW = length($eWord);
	my $len_left = $lenEW - $LOffset;
	my $len_right = $lenEW + $LOffset;
	
	my %simScores = ();
	my %stringSimScores = ();
	my %logSimSimScores = ();
	
	if((exists $hash_unigram{$eWord} and ValidUniGram($eWord,$hash_unigram{$eWord})==1) or (exists $hash_concept{lc($eWord)} and $lenEW>=$minConceptLength)){
		
		$simScores{$eWord}=1;
		$stringSimScores{$eWord}=1;
		$logSimSimScores{$eWord}=1;
	}else{
		if($lenEW>=1){
			
			for my $subDir ( keys %subDirs ) {
				my $maxWL = $subDirs{$subDir};
						
				for(my $i=$len_left; $i<=$len_right; $i++){
					if($i>=1 && $i<=$maxWL){
						my $unifileName = $WLRootDir.$subDir."/".$uniPrefix.$i;
											
						open(UNIFILE,"<$unifileName");
						my $uniG;
						while ($uniG=<UNIFILE>)    
						{
							my @arr=FindToken($uniG);
							my $freq= @arr[1];
							my $stringSim= String_Sim_4($eWord, @arr[0]);
							my $logSim = log($freq)/log($freqThe);
							my $score = $stringSim*$logSim;
							
							if($score<=0){
								next;
							}
							
							$simScores{@arr[0]}=$score;
							$stringSimScores{@arr[0]}=$stringSim;
							$logSimSimScores{@arr[0]}=$logSim;
						}
						close(UNIFILE);	
					}
				}
			}
			
			
		}
	}
	
	my @sortedSimScore = sort { $simScores{$b} <=> $simScores{$a} } keys %simScores;
	
	if($#sortedSimScore>=49){
		@candidates= splice(@sortedSimScore, 0, 49);
	}else{
		@candidates = @sortedSimScore;
	}
	
	@sortedSimScore=();
	
	foreach my $key (@candidates){
		if(exists $hash_dictionary{lc($key)}){
			push @sortedSimScore, $key;
		}
	}
		
	@candidates=();
	@candidates = @sortedSimScore;
		
	return @candidates;
}

####################################################################################
##### Determine string Similarity between two strings using LCS, MCLCS_0, MCLCS_n, MCLCS_z 
####################################################################################
sub String_Sim_4
{
	my($tok1,$tok2)=($_[0],$_[1]);

	$ret_value=LCS($tok1,$tok2);
	$value_NLCS=$ret_value/max(length($tok1),length($tok2));
	$value_MCLCS_0=MCLCS_0($tok1,$tok2);
	$value_MCLCS_n=MCLCS_n($tok1,$tok2);
	$value_MCLCS_z=MCLCS_z($tok1,$tok2);
	return 0.25*$value_NLCS + 0.25*$value_MCLCS_0 + 0.25*$value_MCLCS_n + 0.25*$value_MCLCS_z;		
}

############################################################################################
##### starting from end 
sub MCLCS_z
{
	my($s1,$s2)=($_[0],$_[1]);
	my $min_char_match=1;
	my $val=0;
	if (length($s2)<length($s1))
	{
		my $temp_s=$s1; $temp_l=$len1;
		$s1=$s2;        $len1=$len2;
		$s2=$temp_s;	$len2=$temp_l;

	}
	my $len1=length($s1);
	my $len2=length($s2);

			my $i=1;
			while ($i<=$len1)
			{ 
				my $temp_str1=substr($s1,-($i),$i); 
				my $temp_str2=substr($s2,-($i),$i);
				
				if ($temp_str1 eq $temp_str2)
				{
					$val=length($temp_str1)/max($len1,$len2);
				}
							
				$i++;
			}
					
		
		return $val;
}
############################################################################################
sub MCLCS_n
{
	my($s1,$s2)=($_[0],$_[1]);
	my $min_char_match=1;
	my $val=0;
	if (length($s2)<length($s1))
	{
		my $temp_s=$s1; $temp_l=$len1;
		$s1=$s2;        $len1=$len2;
		$s2=$temp_s;	$len2=$temp_l;

	}
	my $len1=length($s1);
	my $len2=length($s2);
	my $short_str_len=0;
	my $t_len=$t_len1=$len1;
	
		while ($t_len1>0)
		{		
			my $i=0;
			while ($i<=$len1-$t_len1)
			{
				my $temp_str=substr($s1,$i,$t_len1); 
				
				if (index($s2,$temp_str)!=-1)
				{
					$val=length($temp_str)/max($len1,$len2);
				}
	
				if ($val>0)
				{
					return $val;
				}
							
				$i++;
				
			}
			$t_len1=$t_len--;
		}
		
		return 0;
}
####################################################
sub MCLCS_0
{
	my($s1,$s2)=($_[0],$_[1]);
	my $min_char_match=1;
	my $val=0;
	if (length($s2)<length($s1))
	{
		my $temp_s=$s1; $temp_l=$len1;
		$s1=$s2;        $len1=$len2;
		$s2=$temp_s;	$len2=$temp_l;

	}
	my $len1=length($s1);
	my $len2=length($s2);

	while (length($s1)>=$min_char_match)
	{
		if (index($s2,$s1)==0)
		{
			$val=length($s1)/max($len1,$len2);
		}
	
		if ($val>0)
		{
			return $val;
		}
		else 
		{
			chop($s1);
		}
		
	}
	return 0;
}

#### longest common subsequence  ########
sub LCS {     
  my $ew = $_[0];
  my $fw = $_[1];
  my $lenE = length($ew);
  my $lenF = length($fw);
  my @kk;

  for (my $l = 0; $l < $lenE; $l++) {
    $kk[$l] = $lenF;
  }

  for (my $i = 0; $i < $lenE; $i++) {
    for (my $j = $lenF-1; $j >= 0; $j--) {
      if (substr($ew, $i, 1) eq substr($fw, $j, 1)) { 
        my $l = 0;
        while ($j > $kk[$l]) { $l++; }
        $kk[$l] = $j;
      }
    }
  }

  for (my $l = 0; $l < $lenE; $l++) {
    return $l if $kk[$l] == $lenF;
  }
  return $lenE;
}
############################################
