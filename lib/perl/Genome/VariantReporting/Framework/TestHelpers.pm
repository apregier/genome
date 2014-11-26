package Genome::VariantReporting::Framework::TestHelpers;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';
use Test::More;
use Sub::Install qw(reinstall_sub);
use Set::Scalar;
use Params::Validate qw(validate validate_pos :types);
use Genome::Test::Factory::Model::SomaticVariation;
use Genome::Test::Factory::InstrumentData::Solexa;
use Genome::Test::Factory::InstrumentData::MergedAlignmentResult;
use Genome::File::Vcf::Differ;
use Genome::Utility::Test;
use File::Slurp qw(write_file);
use Genome::Utility::Test qw(compare_ok);
use File::Copy qw();

use Exporter 'import';

our @EXPORT_OK = qw(
    test_cmd_and_result_are_in_sync
    get_test_dir
    get_translation_provider
    get_reference_build
    get_translation_provider_with_vep
    test_dag_xml
    test_dag_execute
    test_expert_is_registered
);

sub test_expert_is_registered {
    my $name = shift;

    my $factory = Genome::VariantReporting::Framework::Factory->create();
    my $class = $factory->get_class('experts', $name);
    isa_ok($class,
        'Genome::VariantReporting::Framework::Component::Expert',
        $class->name,
    );
}

sub test_cmd_and_result_are_in_sync {
    my $cmd = shift;

    my %input_hash = $cmd->input_hash;
    my $cmd_set = Set::Scalar->new(keys %input_hash);
    my $sr_set = Set::Scalar->new(
        $cmd->output_result->param_names,
        $cmd->output_result->metric_names,
        $cmd->output_result->input_names,
        $cmd->output_result->transient_names,
    );
    is_deeply($cmd_set - $sr_set, Set::Scalar->new(),
        'All command inputs are persisted SoftwareResult properties');
}

sub get_reference_build {
    my %p = validate(@_, {
        version => {type => SCALAR},
    });
    my $test_dir = get_test_dir('Genome::VariantReporting::Framework::Component::RuntimeTranslations', $p{version});

    my $fasta_file = readlink(File::Spec->join($test_dir, 'reference.fasta'));
    return Genome::Test::Factory::Model::ReferenceSequence->setup_reference_sequence_build($fasta_file);
}

sub get_translation_provider {
    my %p = validate(@_, {
        version => {type => SCALAR},
    });
    my $test_dir = get_test_dir('Genome::VariantReporting::Framework::Component::RuntimeTranslations', $p{version});
    my $fasta_file = readlink(File::Spec->join($test_dir, 'reference.fasta'));
    my @bam_results = setup_bam_results(
        File::Spec->join($test_dir, 'bam1.bam'),
        File::Spec->join($test_dir, 'bam2.bam'),
        $fasta_file,
    );
    return Genome::VariantReporting::Framework::Component::RuntimeTranslations->create(
            translations => {
                aligned_bam_result_id => [map {$_->id} @bam_results],
                reference_fasta => $fasta_file,
            },
    );
}

sub setup_bam_results {
    my ($bam1, $bam2, $reference_fasta) = validate_pos(@_, 1, 1, 1);
    my $bam_result1 = Genome::Test::Factory::InstrumentData::MergedAlignmentResult->setup_object();
    my $bam_result2 = Genome::Test::Factory::InstrumentData::MergedAlignmentResult->setup_object();

    my %bam_result_to_sample_name = (
        $bam_result1->id => get_sample_name($bam1),
        $bam_result2->id => get_sample_name($bam2),
    );
    reinstall_sub( {
        into => 'Genome::InstrumentData::AlignmentResult::Merged',
        as => 'sample_name',
        code => sub {my $self = shift;
            return $bam_result_to_sample_name{$self->id};
        },
    });


    my %result_to_bam_file = (
        $bam_result1->id => $bam1,
        $bam_result2->id => $bam2,
    );
    reinstall_sub( {
        into => 'Genome::InstrumentData::AlignmentResult::Merged',
        as => 'bam_file',
        code => sub {my $self = shift;
            return $result_to_bam_file{$self->id};
        },
    });
    reinstall_sub( {
        into => 'Genome::InstrumentData::AlignmentResult::Merged',
        as => 'reference_fasta',
        code => sub {return $reference_fasta;},
    });

    return ($bam_result1, $bam_result2);
}

sub get_sample_name {
    my $bam = shift;
    my $cmd = Genome::Model::Tools::Sam::GetSampleName->execute(bam_file => $bam);
    return $cmd->sample_name;
}

sub test_dag_xml {
    my ($dag, $test_file) = @_;

    my $expected_xml_path = File::Spec->join($test_file . '.d', 'expected.xml');

    my $xml_path = Genome::Sys->create_temp_file_path;
    write_file($xml_path, $dag->get_xml);

    if ($ENV{GENERATE_TEST_DATA}) {
        File::Copy::copy($xml_path, $expected_xml_path);
    }
    compare_ok($expected_xml_path, $xml_path, "Xml looks as expected");
}

sub test_dag_execute {
    my ($dag, $expected_vcf, $input_vcf, $provider, $variant_type, $plan) = @_;
    $plan->validate();
    $plan->validate_translation_provider($provider);
    $plan->translate($provider->translations);
    my $output = $dag->execute(
        input_vcf => $input_vcf,
        provider_json => $provider->as_json,
        variant_type => $variant_type,
        plan_json => $plan->as_json,
    );
    my $vcf_path = $output->{output_vcf};
    my $differ = Genome::File::Vcf::Differ->new($vcf_path, $expected_vcf);
    my $diff = $differ->diff;
    is($diff, undef, "Found No differences between $vcf_path and (expected) $expected_vcf") ||
        diag $diff->to_string;
}

sub get_test_dir {
    my ($pkg, $VERSION) = validate_pos(@_, 1, 1);

    my $test_dir = Genome::Utility::Test->data_dir($pkg, "v$VERSION");
    if (-d $test_dir) {
        note "Found test directory ($test_dir)";
    } else {
        die "Failed to find test directory ($test_dir)";
    }
    return $test_dir;
}
