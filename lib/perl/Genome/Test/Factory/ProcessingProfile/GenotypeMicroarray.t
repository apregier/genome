#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Test::Factory::ProcessingProfile::GenotypeMicroarray");

my $p = Genome::Test::Factory::ProcessingProfile::GenotypeMicroarray->setup_object();
ok($p->isa("Genome::ProcessingProfile::GenotypeMicroarray"), "Generated a genotype pp");

done_testing;
