#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

my $class = 'Genome::Model::Tools::RegulomeDb::GetAllForRoi';
use_ok($class);

my $roi = "11\t5248049\t5248053\n14\t100705101\t100705104";
my $expected_expanded = "11\t5248049\t5248050\n11\t5248050\t5248051\n11\t5248051\t5248052\n11\t5248052\t5248053\n14\t100705101\t100705102\n14\t100705102\t100705103\n14\t100705103\t100705104";
my $expanded = $class->expand_rois($roi);
is($expanded, $expected_expanded, "ROI expanded correctly");

my $roi1 = "11\t5248049\t5248050";
my $roi2 = "11\t5248052\t5248053";
my $score = "1f";
my $expected_combined = "11\t5248049\t5248053\t1f";
my $combined = $class->combine_rois($roi1, $roi2, $score);
is($combined, $expected_combined, "ROIs combined correctly");

my $score_line1 = "chr11\t5248049\t5248050\trs1;1f";
my $score_line2 = "chr11\t5248050\t5248051\trs1;1f";
my $score_line3 = "chr11\t5248051\t5248052\trs1;3a";
my $score_line4 = "chr11\t5248052\t5248053\trs1;2c";

is($class->extract_score($score_line1), "1f", "score was extracted correctly");

my $input_roi = "11\t5248049\t5248053\tgeneA";
my $expected_processed_roi = "11\t5248049\t5248051\t1f\n11\t5248051\t5248052\t3a\n11\t5248052\t5248053\t2c";
my $modified_roi = $class->process_roi(
    $input_roi,
    $score_line1,
    $score_line2,
    $score_line3,
    $score_line4
);
is($modified_roi, $expected_processed_roi, "ROI was processed correctly");

done_testing;

