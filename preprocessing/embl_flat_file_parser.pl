#!/usr/bin/perl 

$/="//";

$num_args= $#ARGV +1;
if ($num_args !=1){
	print "\nUsage: name $0 embl_flatfile\n";
	exit;
}

$inputfile = $ARGV[0];
open FILE, $inputfile;


# ID   ULIZ01012725; SV 1; linear; genomic DNA; WGS; ENV; 3588 BP.
# XX
# AC   ULIZ01012725;
# XX
# PR   Project:PRJEB28245;
# XX
# DT   29-AUG-2018 (Rel. 137, Created)
# DT   29-AUG-2018 (Rel. 137, Last updated, Version 1)
# XX
# DE   human gut metagenome genome assembly, contig: scaffold12081_2
# XX
# KW   WGS;.
# XX
# OS   human gut metagenome
# OC   unclassified sequences; metagenomes; organismal metagenomes.
# XX
# RN   [1]
# RA   Lee J., Jie Z.;
# RT   ;
# RL   Submitted (17-AUG-2018) to the INSDC.
# RL   BGI, Metagenomics group, Yantian District, Shenzhen, Guangdong, China
# XX
# DR   MD5; cbc9320c07b66947caf2bcc243663915.
# DR   ENA; ULIZ01000000; SET.
# DR   ENA; ULIZ00000000; SET.
# DR   BioSample; SAMEA4835456.
# XX
# FH   Key             Location/Qualifiers
# FH
# FT   source          1..3588
# FT                   /organism="human gut metagenome"
# FT                   /environmental_sample
# FT                   /mol_type="genomic DNA"
# FT                   /isolation_source="fecal sample"
# FT                   /note="contig: scaffold12081_2"
# FT                   /db_xref="taxon:408170"
# FT                   /lat_lon="38.6375 N 90.2651 W
# XX

while($line=<FILE>){
	chomp $line;
	@lines = split(/\n/, $line);
	$taxonomy="NA";
	@taxum =grep (/\"taxon/, @lines);
	if (@taxum){
		$taxum[0]=~/.+?db_xref\=\"taxon[\:\=]{1}(.+?)\"/i;
		$taxonomy=$1;
        }


	@rc = grep (/^RC/, @lines);
	$rclit='';
	if (@rc){
                foreach my $x (@rc){
                        $x=~/RC\s+(.+)/;
                        $rclit=$rclit ." || ". $1;
                }
        }

	else{
             	$rclit="NA";
        }

	@ra = grep (/^RA/, @lines);
        $ralit='';
        if (@ra){
                foreach my $x (@ra){
                        $x=~/RA\s+(.+)/;
                        $ralit=$ralit ." || ". $1;
                }
        }

	else{
             	$ralit="NA";
        }



	@rl = grep (/^RL/, @lines);
	$rlit='';

        if (@rl){
		foreach my $x (@rl){
	                $x=~/RL\s+(.+)/;
			$rlit=$rlit ." || ". $1;
		}
        }

	else{
             	$rlit="NA";
        }

	@rx = grep (/^RX/, @lines);
	$rlex='';
	if (@rx){
                foreach my $x (@rx){
                        $x=~/RX\s+(.+)/;
                        $rlex=$rlex ." || ". $1;
                }
        }

	else{
             	$rlex="NA";
        }
	@lit = grep (/^RX/, @lines);
	$doi="NA";
	$pmid="NA";
	if (@lit){
		@doi=grep(/DOI/, @lit);
		@pubmed=grep(/PUBMED/, @lit);
		if (@doi){
			$doi[0] =~/RX\s+DOI\;(.*)/;
			$doi=$1;
			$doi=~s/\.$//;
			$doi=~s/^\.//;
		}
		else{
			$doi = "NA";
		}
		if (@pubmed){
			$pubmed[0] =~/RX\s+PUBMED\;(.+)/;
			$pmid=$1;
			$pmid=~s/\.$//;
		}
		else{
			$pmid="NA";
		}
	}
	@drs = grep (/^DR/, @lines);
        $pmcid="NA";
	if (@drs){
                @pmc=grep(/EuropePMC/, @drs);
		if(@pmc){
			$pmc[0] =~/DR\s+EuropePMC\;(.*?)\;/;
               		$pmcid=$1;
		}
		else{
			$pmcid="NA";
		}
        }

	@cc = grep (/^CC/, @lines);
	$comment="";
	if (@cc){
		foreach $x (@cc){
			#print "$x\n";			
			$x =~/CC\s+(.*)$/;
			
			$thiscomment = $1;
			$thiscomment =~s/\n$/ /;
			$thiscomment =~s/\:|\#/ /g;
			$thiscomment =~s/\s+|\t+/ /g;
			$comment .= " ". $thiscomment;
		}
	}
        else {
		$comment="NA";
	}

	@rt =  grep (/^RT/, @lines);
	$title ="";
	if (@rt){
                foreach $x (@rt){
                        #print "$x\n";
                        $x =~/RT\s+(.*)$/;

                        $thiscomment = $1;
                        $thiscomment =~s/\n$/ /;
                        $thiscomment =~s/\"|\;/ /g;
                        $thiscomment =~s/\:|\#/ /g;
                        $thiscomment =~s/\s+|\t+/ /g;
                        $title .= " ". $thiscomment;
                }
        }
	else {
              	$title="NA";
        }
	
        @de =  grep (/^DE/, @lines);
        $descript ="";
        if (@de){
                foreach $x (@de){
                        #print "$x\n";
                        $x =~/DE\s+(.*)$/;

                        $thiscomment = $1;
                        $thiscomment =~s/\n$/ /;
                        $thiscomment =~s/\"|\;/ /g;
                        $thiscomment =~s/\:|\#/ /g;
                        $thiscomment =~s/\s+|\t+/ /g;
                        $descript .= " ". $thiscomment;
                }
        }
	else {
              	$descript="NA";
        }


	@ac = grep (/^ID/, @lines);
	$acc="NA";
	$taxgroup="NA";
	if (@ac){
		$ac[0]=~/^ID\s+(.+?)\;/;
		$acc=$1;
		@taxg = split(/\;\s+/, $ac[0]);
		$taxgroup = $taxg[5];
	}
	# PR   Project:PRJNA33253;
	@pr =grep (/^PR/, @lines);
	$project="NA";
	if (@pr){
		print "$_\n";
		@proj =grep(/Project:/,@pr);
		if (@proj){
			$proj[0]=~/PR\s+Project\:(.+?)\;/;
			$project = $1;
		}
		else{
			$project = "NA";
		}
	}
	
	@os =grep (/^OS/, @lines);
        if (@os){
		$os[0]=~/OS\s+(.+)/;
        	$organism=$1;
	}
	else {
		$organism="NA";
	}
		
	@biosam =grep (/BioSample/, @lines);
        if (@biosam){
      		$biosam[0]=~/.+?Biosample\;\s+(.+?)\./i;
        	$bio = $1;
	}
	else{
		$bio="NA";
	}
	@ft_taxon=grep(/^FT/, @lines);	
	$tax_id="NA";
	if (@ft_taxon){
		@taxon =grep (/db_xref.*?taxon/, @ft_taxon);
		if(scalar(@$taxon) > 0){
			$taxon[0]=~/.+?db_xref\=\"taxon[\:\=]{1}(.+?)\"/i;
			$tax_id=$1;
		}
		else{
			$tax_id="NA";
			#print "ALAKO\n";
		}
	}
	
	@geo =grep (/lat_lon/, @ft_taxon);
	if (@geo){
        	$geo[0]=~/.+?lat_lon\=\"(.+?)\"/;
	        $geos=$1;
	}
	else{
		$geos="NA";
	}

	@source =grep (/isolation_source/, @lines);
        if (@source){
                $source[0]=~/.+?isolation_source=\"(.+?)\"/;
                $sources = $1;
        }
	else{
             	$sources = "NA";
        }

	@dates =grep (/collection_date/, @lines);
        if (@dates){
                $dates[0]=~/.+?collection_date=\"(.+?)\"/;
                $date = $1;
        }
	else{
             	$date = "NA";
        }

	$pays="NA";
	$pays_2="NA";
	@country =grep (/\/country/, @lines);
        if (@country){
                $country[0]=~/.+?country=\"(.+)/;
                $pays = $1;
		$pays=~s/\"//;
		@ps = split(/\:/, $pays);
		$pays_short = $ps[0];

        }

	@note =grep (/\/note/, @lines);
        if (@note){
                $note[0]=~/.+?note=\"(.+)/;
                $pays_2 = $1;
        }
	else{
             	$pays_2 = "NA";
        }


	@dt =grep (/^DT/, @lines);
	$public="NA";
        if (@dt){
        	$dt[0]=~/DT\s+(.+?)\(/;
        	$public = $1;
        }

	@subm =grep (/^RL/, @lines);
	$submit="NA";
        if (@subm){
		@s= grep(/Submitted/, @subm);
		if (@s){
                	$s[0]=~/RL\s+Submitted \((.+?)\).*/;
                	$submit = $1;
		}	
       		else{
                	$submit="NA";
       		}
	}
	
	@lat_lon =grep (/\/lat_lon/, @lines);
        if (@lat_lon){
                $lat_lon[0]=~/.+?lat_lon=\"(.+?)\"/;
                $geo_loc = $1;
        }
	else{
             	$geo_loc = "NA";
        }
	
	print join ("\t",$acc, $pmid, $doi, $pmcid, $project, $pays,  $pays_short, $submit, $public, $geos, $organism, $taxonomy, $taxgroup, $comment, $title, $descript), "\n" if $pays ne "NA" || $geos ne "NA";
	$taxonomy="";
	$organism="";
	$geos="";
	$tax="";
	$tax_id="";
	$acc="";
	$project="";
	$organism="";
	$bio="";
	$tax="";
	$geos="";
	$sources="";
	$date="";
	$or="";
	$rclit="";
	$rlit="";
	$rlex="";
	$pays="";
	$ralit="";
	$pays_2="";
	$pays_short="";
	$public="";
	$submit="";
	$pmid="";
	$doi="";
	$pmcid ="";
	$taxgroup="";
	$comment="";
	$title="";
	$descript="";
}


