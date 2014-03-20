#! /gsc/bin/perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above 'Genome';

require Genome::Utility::Test;
use Genome::Test::Factory::Model::ImportedReferenceSequence;
use Genome::Test::Factory::Build;
use Test::More;

my $class = 'Genome::InstrumentData::BamUtil::ClipOverlapResult';
use_ok($class) or die;


Sub::Install::reinstall_sub({
    into => $class, # TODO should this be the result->execute instead?
    as => '_run_clip_overlap',
    code => sub { return 1; },
});

my $bam_source = Genome::InstrumentData::AlignmentResult::Merged->__define__();
my $test_dir = Genome::Sys->create_temp_directory;

my $reference_model = Genome::Test::Factory::Model::ImportedReferenceSequence->setup_object();
my $reference_build = Genome::Test::Factory::Build->setup_object(
    model_id => $reference_model->id,
    data_directory => $test_dir,
);

my $result = $class->create(
    reference_build => $reference_build,
    bam_source => $bam_source,
    version => "1.0.11",
);

ok($result, "Software result was created");

my $get_result = $class->get($result->id);

ok($get_result, "Able to get the result that we created");

is($get_result->id, $result->id, "Ids match");

done_testing();

=cut 
my $version = "1";
my $data_dir = Genome::Utility::Test->data_dir_ok($class, $version);

my $in = File::Spec->join($data_dir, "testClipOverlapCoord.sam");
my $expected_out = File::Spec->join($data_dir, "testClipOverlapCoord.expected.sam");
my $out = Genome::Sys->create_temp_file_path;

my $cmd = $class->create(
    input_bam => $in,
    output_bam => $out,
);

ok($cmd, "Command was created correctly");
ok($cmd->execute, "Command was executed successfuly");
ok(-s $out, "Output file exists");
compare_ok($out, $expected_out, "Output file was as expected");

done_testing;
