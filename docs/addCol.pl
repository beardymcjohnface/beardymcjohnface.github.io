use strict;
use warnings;

my $usage = "
perl addCol.pl  chr.kar  links.tsv > newlinks.tsv
";

my $kar = shift or die $usage;
my $links = shift or die $usage;

my %cols;

open my $K, '<', $kar or die;
while(<$K>){
    my @l=split/\s+/;
    $cols{$l[2]}=$l[6];
}
close $K or die;

open my $L, '<', $links or die;
while(<$L>){
    my @l=split/\s+/;
    $l[6] .= ",color=$cols{$l[0]}";
    (print STDOUT "$_ ") for (@l);
    print STDOUT "\n";
}
close $L or die;
