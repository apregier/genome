#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Exception;
use Genome::File::Vcf::Entry;

my $pkg = 'Genome::File::Vcf::DbsnpAFParser';
use_ok($pkg);

my $header_4x1 = create_vcf_header_4x1();
my $parser = $pkg->new($header_4x1);
ok($parser, 'construct parser');
isa_ok($parser, 'Genome::File::Vcf::DbsnpAFParserForInfoTypeDot');

subtest "three alleles" => sub {
    my $entry = create_entry_4x1("[0.25,0.40,0.35]");
    my $expected = {
        A => 0.25,
        C => '0.40',
        G => 0.35,
    };
    is_deeply($parser->process_entry($entry), $expected, "Processed CAF with three alleles");
};

subtest "malformed CAF" => sub {
    my $entry = create_entry_4x1("0.4,0.5");
    throws_ok(sub {$parser->process_entry($entry)}, qr(Invalid CAF entry));
};

subtest "different length of caf list" => sub {
    my $entry = create_entry_4x1("[0.4]");
    throws_ok(sub {$parser->process_entry($entry)}, qr(Frequency list and allele list differ in length));
};

subtest "No CAF entry" => sub {
    my $entry = create_entry_4x1();
    is($parser->process_entry($entry), undef, "No caf entry returned undef");
};

my $header_4x2 = create_vcf_header_4x2();
my $parser_4x2 = $pkg->new($header_4x2);
ok($parser_4x2, 'construct parser');
isa_ok($parser_4x2, 'Genome::File::Vcf::DbsnpAFParserForInfoTypeR');

subtest "three alleles" => sub {
    my $entry = create_entry_4x2("[0.25,0.40,0.35]");
    my $expected = {
        A => 0.25,
        C => '0.40',
        G => 0.35,
    };
    is_deeply($parser->process_entry($entry), $expected, "Processed CAF with three alleles");
};

subtest "No CAF entry" => sub {
    my $entry = create_entry_4x2();
    is($parser->process_entry($entry), undef, "No caf entry returned undef");
};

done_testing;

###

# 4x1
sub create_vcf_header_4x1 {
    my $header_txt = <<EOS;
##fileformat=VCFv4.1
##INFO=<ID=CAF,Number=.,Type=Float,Description="Info field A">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
EOS
    my @lines = split("\n", $header_txt);
    my $header = Genome::File::Vcf::Header->create(lines => \@lines);
    return $header
}

sub create_entry_4x1 {
    my $caf = shift;
    my @fields = (
        '1',            # CHROM
        10,             # POS
        '.',            # ID
        'A',            # REF
        'C,G',            # ALT
        '10.3',         # QUAL
        '.',         # FILTER
    );

    if ($caf) {
        push @fields, "CAF=$caf";
    }

    my $entry_txt = join("\t", @fields);
    my $entry = Genome::File::Vcf::Entry->new(create_vcf_header_4x1(), $entry_txt);
    return $entry;
}

# 4x2
sub create_vcf_header_4x2 {
    my $header_txt = <<EOS;
##fileformat=VCFv4.2
##INFO=<ID=CAF,Number=R,Type=Float,Description="Info field A">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
EOS
    my @lines = split("\n", $header_txt);
    my $header = Genome::File::Vcf::Header->create(lines => \@lines);
    return $header
}

sub create_entry_4x2 {
    my $caf = shift;
    my @fields = (
        '1',            # CHROM
        10,             # POS
        '.',            # ID
        'A',            # REF
        'C,G',            # ALT
        '10.3',         # QUAL
        '.',         # FILTER
    );

    if ($caf) {
        push @fields, "CAF=$caf";
    }

    my $entry_txt = join("\t", @fields);
    my $entry = Genome::File::Vcf::Entry->new(create_vcf_header_4x2(), $entry_txt);
    return $entry;
}

