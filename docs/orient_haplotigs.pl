#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use List::Util qw(min max);
use Statistics::LineFit;

# This script will use the placement information from a purge_haplotigs ncbiplace run to create an oriented haplotigs
# FASTA file. This can be used to order the haplotigs to the primary contigs, or, to orient a haploid assembly to 
# a reference genome.


# pre flight checks
check_programs("samtools");


# global vars
my $haplotigs;
my $primaries;
my $placements;
my $TMP = "tmp_purge_haplotigs/PLACE";
my $out = "oriented";
my $scaffold;
my $dont_rename;
my $tac_contigs;

my %alignments;     # $alignments{primary}{haplotig}{D} = direction (+/-)
                    #                               {C} = weighted centroid (relative to primary)
my %cent;           # $cent{haplotig}{c} = array of centroid positions
                    #                {b} = array of align lengths
my @primaries;      # This is purely to order the haplotig ouput

my $usage = "

USAGE:
orient_haplotigs.pl  -p primary_contigs.fa  -h haplotigs.fa  -n ncbi_placements.tsv  [ -d temp_ncbi_placements_dir -o outprefix]

REQUIRED:
-p      primary contigs FASTA
-h      haplotigs FASTA
-n      ncbi placement file from purge_haplotigs ncbiplace

OPTIONAL:
-d      temp directory produced from purge_haplotigs ncbiplace, DEFAULT = $TMP
-o      output file prefix, DEFAULT = $out
-s      pseudo scaffold the haplotigs together (also produces a bed file annotation of the contigs)
-r      don't rename contigs
-t      tac unaligned contigs on the end
";


# parse and check args
GetOptions (
    "p=s" => \$primaries,
    "h=s" => \$haplotigs,
    "n=s" => \$placements,
    "d=s" => \$TMP,
    "o=s" => \$out,
    "s" => \$scaffold,
    "r" => \$dont_rename,
    "t" => \$tac_contigs
) or die $usage;

($primaries) && ($haplotigs) && ($placements) || err($usage);


# cleanup old output and open output filehandles
((-s "$_") && (unlink $_)) for  ("$out.fasta", "$out.bed");
open my $OFH, ">", "$out.fa" or err("Failed to open $out.fa for writing");
($scaffold) && (open my $BED, ">", "$out.bed" or err("Failed to open $out.bed for writing"));


# check FASTAs
check_files($haplotigs, $primaries);
( (-s "$_.fai") || runcmd({ command => "samtools faidx $_" }) ) for ($primaries, $haplotigs);


# get the primary contig order
open my $PFH, "<", "$primaries.fai" or err("Failed to open $primaries.fai for reading");
while(<$PFH>){
    my @l = split(/\s+/,$_);
    push @primaries, $l[0];
}
close $PFH;


# parse the placements file
open my $PL, $placements or err("failed to open $placements for reading");

while(<$PL>){
    next if ($_ =~ /^#/);
    my @l = split(/\s+/,$_);
    $alignments{$l[4]}{$l[2]}{D} = $l[5];
}

close $PL;

# get the centroid for each haplotig

# get the PAF file name from the p- and h- ctg file names
my $pp = $primaries;
my $hp = $haplotigs;
$pp =~ s/.f[astn]+$//;
$hp =~ s/.f[astn]+$//;
my $alignFile = "$TMP/$pp-$hp.paf.gz";

if (!(-s $alignFile)){
    msg("Running minimap2 hit search");
    runcmd({ command => "minimap2 --secondary=no -r 10000 -t 8 $primaries $haplotigs 2> $TMP/minimap2.stderr | sort -k6,6 -k8,8n | gzip - > $alignFile.tmp",
             logfile => "$TMP/minimap2.stderr",
             silent => 1 });
    rename "$alignFile.tmp", "$alignFile";
    msg("Minimap2 hit search done");
}

# open pipe to PAF alignment, slurp the centroids of the relevant alignments
open my $PAF, '-|', "zcat $alignFile" or err("Failed to open pipe zcat $alignFile |");
while(<$PAF>){
    my@l=split/\s+/;
    if (defined($alignments{$l[5]}{$l[0]})){
        push @{$cent{$l[0]}{c}}, (($l[7] + $l[8]) / 2);
        push @{$cent{$l[0]}{r}}, (($l[2] + $l[3]) / 2);
        push @{$cent{$l[0]}{b}}, ($l[8] - $l[7]) / 100;
    }
}
close $PAF or err("Failed to close filehandle for pipe zcat $alignFile |");


# calculate the median of the alignment centroiods for contig pairs and work out direction
P: for my $primary (keys %alignments){
    H: for my $haplotig (keys %{$alignments{$primary}}){
        next H unless defined($cent{$haplotig});
        my $c = $cent{$haplotig};
        
        # check direction using centroids, make them weighted based on alignment length
        if (scalar(@{$$c{c}})>1){
            my $fit = Statistics::LineFit->new();
            my @x;
            my @y;
            for my $i (0..$#{$$c{c}}){
                (push @x, @{$$c{r}}[$i]) for (0..@{$$c{b}}[$i]);
                (push @y, @{$$c{c}}[$i]) for (0..@{$$c{b}}[$i]);
            }
            $fit->setData(\@x, \@y);
            if (defined $fit->rSquared()) {
                my ($intercept, $slope) = $fit->coefficients();
                if ($slope < 0){
                    $alignments{$primary}{$haplotig}{D} = '-';
                } else{
                    $alignments{$primary}{$haplotig}{D} = '+';
                }
            }
        }
        
        my $runningLen;
        my $runningCentroid;
        for my $i (0..$#{$$c{c}}){
            $runningLen += @{$$c{b}}[$i] * 100;
            $runningCentroid += @{$$c{b}}[$i] * @{$$c{c}}[$i];
        }
        $alignments{$primary}{$haplotig}{C} = $runningCentroid / $runningLen;
    }
}



# iterate the contigs and print out the oriented haplotigs
for my $primary (@primaries){
    
    # scaffolding options (ignored otherwise)
    my $scaffold_seq;
    my $bed_position=0;
    
    my $count=0;
    next if ($primary eq "na");
    
    # iterate haplotigs
    for my $haplotig (sort { $alignments{$primary}{$a}{C} <=> $alignments{$primary}{$b}{C} } keys %{$alignments{$primary}}){
        
        # new contig name
        my $htig_out = $haplotig;
        if (!($dont_rename)){
            $htig_out =~ s/\|.+//;
            $htig_out = $primary . ".H-" . sprintf("%03d", $count) . " " .$htig_out . " " . $alignments{$primary}{$haplotig}{C};
            $count++;
        }
        
        # grab the sequence, remove whitespace
        my $seq = `samtools faidx $haplotigs \"$haplotig\"`;
        $seq =~ s/>.+\n//;
        ($seq) or err("Failed to slup sequence for $haplotig via samtools faidx");
        $seq =~ s/\s//g;
        if ($alignments{$primary}{$haplotig}{D} eq '-'){
            $seq = scalar reverse $seq;
            $seq =~ tr/ACGTacgtN/TGCAtcgaN/;
        }
        
        # print the seq
        if ($scaffold) {
            if ($scaffold_seq) {
                $scaffold_seq .= ("N" x 100);
                $bed_position += 100;
            }
            print $BED "$primary\t$bed_position\t" . ($bed_position + length($seq)) . "\t$haplotig\t" . length($seq) . "\t$alignments{$primary}{$haplotig}{D}\n";
            $bed_position += length($seq);
            $scaffold_seq .= $seq;
        } else {
            print $OFH ">$htig_out\n";
            print $OFH (print_seq($seq));
        }
    }
    
    # print the scaffold seq
    if (($scaffold) && ($scaffold_seq)){
        print $OFH ">$primary\n";
        print $OFH (print_seq($scaffold_seq));
    }
}

# tack on unaligned seqs
if ($tac_contigs){
    for my $primary (keys(%alignments)){
        if ($primary eq "na"){
            for my $haplotig (keys(%{$alignments{$primary}})){
                print $OFH `samtools faidx $haplotigs \"$haplotig\"`;
            }
        }
    }
}


close $OFH;
close $BED if ($scaffold);
msg("Finished!");
exit(0);


sub print_seq {
    my $seq = shift;
    my $out;
    for (my $i=0; $i < length($seq); $i += 60){
        $out .= substr($seq, $i, (($i+60)>length($seq) ? length($seq) - $i : 60) );
        $out .= "\n";
    }
    return $out;
}



# pipeutils functions

use Time::Piece;


sub print_message {
    my $t = localtime;
    my $line = "[" . $t->dmy . " " . $t->hms . "] @_\n";
    print STDERR $line;
    print $::LOG $line if ($::LOG);
}

sub msg {
    print_message("INFO: @_");
}

sub err {
    print_message("ERROR: @_\n\nPIPELINE FAILURE\n");
    exit(1);
}

sub runcmd {
    my $job = shift;
    ($job->{silent}) || print_message("RUNNING: $job->{command}");
    if (system("$job->{command}") != 0){
        print_message("ERROR: Failed to run $job->{command}");
        print_message("Check $job->{logfile} for possible errors") if ($job->{logfile});
        err("Exiting due to job failure");
    } else {
        ($job->{silent}) || print_message("FINISHED: $job->{command}");
    }
}

sub qruncmd {
    system(@_) == 0 or err("Failed to run @_\n");
}

sub check_files {
    my $check=1;
    foreach(@_){
        if (!(-s $_)){
            print_message("ERROR: file \"$_\" does not exist or is empty");
            $check=0;
        }
    }
    return $check;
}

sub check_programs {
    my $chk=1;
    my $t = localtime;
    my $line = "[" . $t->dmy . " " . $t->hms . "]";
    foreach my $prog (@_){
        print STDERR "$line CHECKING $prog... ";
        my $notexists = `type $prog 2>&1 1>/dev/null || echo 1`;
        if ($notexists){
            print STDERR "ERROR: missing program $prog\n";
            $chk = 0;
        } else {
            print STDERR "OK\n";
        }
    }
    return $chk;
}


