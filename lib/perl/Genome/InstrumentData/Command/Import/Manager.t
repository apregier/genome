#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";
use Data::Dumper;
require Genome::Utility::Test;
use File::Temp;
use Test::More;

use_ok('Genome::InstrumentData::Command::Import::Manager') or die;

class Reference { has => [ name => {}, ], };
my $ref = Reference->create(id => -333, name => 'reference-1');
ok($ref, 'created reference');
class Genome::Model::Ref {
    is => 'Genome::Model',
    has_param => [
        aligner => { is => 'Text', },
    ],
    has_input => [
        reference => { is => 'Reference', },
    ],
};
sub Genome::Model::Ref::_execute_build { return 1; }
my $pp = Genome::ProcessingProfile::Ref->create(id => -333, name => 'ref pp #1', aligner => 'bwa');
ok($pp, 'create pp');

my $sample_name = 'TeSt-0000-00';
my $source_files = 'original.bam';

my $test_dir = Genome::Utility::Test->data_dir_ok('Genome::InstrumentData::Command::Import::Manager', 'v1');
my $working_directory = File::Temp::tempdir(CLEANUP => 1);
my $info_tsv = $working_directory.'/info.tsv';
Genome::Sys->create_symlink($test_dir.'/valid-import-needed/info.tsv', $info_tsv);
my $config_yaml = $working_directory.'/config.yaml';
Genome::Sys->create_symlink($test_dir.'/valid-import-needed/config.yaml', $config_yaml);

# Sample needed
my $manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $working_directory,
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');
my $sample_hash = eval{ $manager->samples->{$source_files}; };
ok($sample_hash, 'sample hash');
is($sample_hash->{status}, 'sample_needed', 'status is sample_needed');
is($sample_hash->{name}, $sample_name, 'sample hash sample name');
ok(!$sample_hash->{sample}, 'sample hash sample does not exist');
ok(!$sample_hash->{instrument_data}, 'sample hash instrument data does not exist');
ok(!$sample_hash->{model}, 'sample hash model does not exist');
ok(!$sample_hash->{build}, 'sample hash build does not exist');

# Define sample
my $sample = Genome::Sample->__define__(
    id => -111,
    name => $sample_name,
    nomenclature => 'TeSt',
);

# Import needed
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $working_directory,
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');
$sample_hash = eval{ $manager->samples->{$source_files}; };
ok($sample_hash, 'sample hash');
is($sample_hash->{status}, 'import_needed', 'status is import_needed');
is($sample_hash->{name}, $sample_name, 'sample hash sample name');
is($sample_hash->{sample}, $sample, 'sample hash sample');
ok(!$sample_hash->{instrument_data}, 'sample hash instrument data does not exist');
ok(!$sample_hash->{model}, 'sample hash model does not exist');
ok(!$sample_hash->{build}, 'sample hash build does not exist');

# Import pend
unlink($info_tsv, $config_yaml);
Genome::Sys->create_symlink($test_dir.'/valid-import-pend/info.tsv', $info_tsv);
Genome::Sys->create_symlink($test_dir.'/valid-import-pend/config.yaml', $config_yaml);
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $working_directory,
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');
$sample_hash = eval{ $manager->samples->{$source_files}; };
ok($sample_hash, 'sample hash');
is($sample_hash->{status}, 'import_pend', 'status is import_pend');
is($sample_hash->{job_status}, 'pend', 'sample hash job status');
is($sample_hash->{name}, $sample_name, 'sample hash sample name');
is($sample_hash->{sample}, $sample, 'sample hash sample');
ok(!$sample_hash->{instrument_data}, 'sample hash instrument data does not exist');
ok(!$sample_hash->{model}, 'sample hash model does not exist');
ok(!$sample_hash->{build}, 'sample hash build does not exist');

is(
    $manager->_resolve_instrument_data_import_command_for_sample($sample_hash),
    "echo $sample_name genome instrument-data import basic --sample name=$sample_name --source-files original.bam --import-source-name TeSt --instrument-data-properties lane='8'",
    'inst data import command',
);

# Unsuccessful import has left inst data entity, but no data file
my $inst_data = Genome::InstrumentData::Imported->__define__(
    original_data_path => $source_files,
    sample => $sample,
    subset_name => '1-XXXXXX',
    sequencing_platform => 'solexa',
    import_format => 'bam',
    description => 'import test',
);
$inst_data->add_attribute(attribute_label => 'read_count', attribute_value => 1000);
$inst_data->add_attribute(attribute_label => 'read_length', attribute_value => 100);

unlink($info_tsv, $config_yaml);
Genome::Sys->create_symlink($test_dir.'/valid-build/info.tsv', $info_tsv);
Genome::Sys->create_symlink($test_dir.'/valid-build/config.yaml', $config_yaml);

$manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $working_directory,
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');
$sample_hash = eval{ $manager->samples->{$source_files}; };
ok($sample_hash, 'sample hash');
is($sample_hash->{status}, 'import_failed', 'status is import_failed');
is($sample_hash->{name}, $sample_name, 'sample hash sample name');
is($sample_hash->{sample}, $sample, 'sample hash sample');
ok($sample_hash->{instrument_data}, 'sample hash instrument');
ok(!$sample_hash->{model}, 'sample hash model does not exist');
ok(!$sample_hash->{build}, 'sample hash build does not exist');

# Successful import, point bam_path to existing file
$inst_data->add_attribute(attribute_label => 'bam_path', attribute_value => $config_yaml);

$manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $working_directory,
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');
$sample_hash = eval{ $manager->samples->{$source_files}; };
ok($sample_hash, 'sample hash');
is($sample_hash->{status}, 'build_needed', 'status is build_needed');
is($sample_hash->{name}, $sample_name, 'sample hash sample name');
is($sample_hash->{sample}, $sample, 'sample hash sample');
ok($sample_hash->{instrument_data}, 'sample hash instrument');
ok($sample_hash->{model}, 'sample hash model');
is_deeply([$sample_hash->{model}->instrument_data], [$inst_data], 'model has instrument data assigned');
ok(!$sample_hash->{model}->auto_assign_inst_data, 'model auto_assign_inst_data is off');
ok(!$sample_hash->{model}->auto_build_alignments, 'model auto_build_alignments is off');
ok(!$sample_hash->{model}->build_requested, 'model build_requested is off');
ok(!$sample_hash->{build}, 'sample hash build does not exist');

# fail - no config file
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $test_dir.'/invalid-no-config-yaml',
);
ok($manager, 'create manager');
ok(!$manager->execute, 'execute failed');
is($manager->error_message, "Property 'config_file': Config file does not exist! ".$manager->config_file, 'correct error');

# fail - no config file
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $test_dir.'/invalid-no-info-file',
);
ok($manager, 'create manager');
ok(!$manager->execute, 'execute failed');
is($manager->error_message, "Property 'info_file': Sample info file does not exist! ".$manager->info_file, 'correct error');

# fail - no name column in csv
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    working_directory => $test_dir.'/invalid-no-name-column-in-info-file',
);
ok($manager, 'create manager');
ok(!$manager->execute, 'execute failed');
is($manager->error_message, 'Property \'info_file\': No "sample_name" column in sample info file! '.$manager->info_file, 'correct error');

done_testing();
