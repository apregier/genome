#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use above 'Genome';
use Genome::Utility::Test qw(compare_ok);
use Genome::VariantReporting::Framework::TestHelpers qw(
    get_translation_provider
    test_dag_xml
    test_dag_execute
    get_test_dir
);
use Genome::VariantReporting::Framework::Plan::TestHelpers qw(
    set_what_interpreter_x_requires
);
use Sub::Install qw(reinstall_sub);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

my $pkg = 'Genome::VariantReporting::Suite::Joinx::ThousandGenomes::Expert';
use_ok($pkg) || die;
my $factory = Genome::VariantReporting::Framework::Factory->create();
isa_ok($factory->get_class('experts', $pkg->name), $pkg);

my $VERSION = 3; # Bump these each time test data changes
my $RESOURCE_VERSION = 1;
my $test_dir = get_test_dir($pkg, $VERSION);

my $expert = $pkg->create();
my $dag = $expert->dag();
test_dag_xml($dag, __FILE__);

set_what_interpreter_x_requires('1kg');
my $plan = Genome::VariantReporting::Framework::Plan::MasterPlan->create_from_file(
    File::Spec->join($test_dir, 'plan.yaml'),
);
$plan->validate();

my $variant_type = 'snvs';
my $expected_vcf = File::Spec->join($test_dir, "expected_$variant_type.vcf.gz");
my $provider = get_translation_provider(version => $RESOURCE_VERSION);
$provider->translations({"1kg_vcf" => File::Spec->join($test_dir, '1kg.vcf')});

my $input_vcf = File::Spec->join($test_dir, "$variant_type.vcf.gz");
test_dag_execute($dag, $expected_vcf, $input_vcf, $provider, $variant_type, $plan);
done_testing();
