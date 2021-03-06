#!/usr/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Sys') or die;

# Submit job that should work
my @job_ids;
my $cmd = 'ls ~';
my $job_id = Genome::Sys->bsub(
    queue => $ENV{GENOME_LSF_QUEUE_SHORT},
    cmd => $cmd,
);
ok($job_id, "bsubbed $cmd, got job id back");
push @job_ids, $job_id;

# Submit job that should fail
$cmd = 'exit 1';
$job_id = Genome::Sys->bsub(
    queue => $ENV{GENOME_LSF_QUEUE_SHORT},
    cmd => $cmd
);
ok($job_id, "bsubbed $cmd, got job id back");
push @job_ids, $job_id;
my $job_that_should_fail = $job_id;

# Wait for jobs to come back
my %job_statuses = Genome::Sys->wait_for_lsf_jobs(@job_ids);
ok(%job_statuses, 'got job status hash back from wait_for_lsf_jobs method');

my @keys = keys %job_statuses;
ok(@keys == @job_ids, 'job status hash has same number of keys as submitted jobs');

for my $job_id (@job_ids) {
    my $status = $job_statuses{$job_id};
    ok($status, "got status for job $job_id, $status");
    if ($job_id eq $job_that_should_fail) {
        is($status, 'EXIT', "job $job_id failed as expected");
    }
    else {
        is($status, 'DONE', "job $job_id succeeded as expected");
    }
}

done_testing;
