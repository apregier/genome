#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More; #skip_all => 'archiving not fully implemented yet';
use File::Temp 'tempdir';
use Filesys::Df qw();

use_ok('Genome::Disk::Allocation') or die;
use_ok('Genome::Disk::Volume') or die;

use Genome::Disk::Allocation;
$Genome::Disk::Allocation::CREATE_DUMMY_VOLUMES_FOR_TESTING = 0;

# Temp testing directory, used as mount path for test volumes and allocations
my $test_dir = tempdir(
    'allocation_testing_XXXXXX',
    TMPDIR => 1,
    UNLINK => 1,
    CLEANUP => 1,
);

# Create test group
my $group = Genome::Disk::Group->create(
    disk_group_name => 'test',
    subdirectory => 'info',
    permissions => '775',
    setgid => 1,
    unix_uid => '1',
    unix_gid => '1',
);
ok($group, 'created test disk group');

# Create temp archive volume
my $archive_volume_path = tempdir(
    "test_volume_XXXXXXX",
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
my $archive_volume = Genome::Disk::Volume->create(
    hostname => 'test',
    physical_path => 'test',
    mount_path => $archive_volume_path,
    disk_status => 'active',
    can_allocate => 1,
    total_kb => Filesys::Df::df($archive_volume_path)->{blocks},
);
ok($archive_volume, 'created test volume');

# Create temp active volume
my $volume_path = tempdir(
    "test_volume_XXXXXXX",
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
my $volume = Genome::Disk::Volume->create(
    hostname => 'test',
    physical_path => 'test',
    mount_path => $volume_path,
    disk_status => 'active',
    can_allocate => 1,
    total_kb => Filesys::Df::df($volume_path)->{blocks},
);
ok($volume, 'created test volume');

my $assignment = Genome::Disk::Assignment->create(
    group => $group,
    volume => $volume,
);
ok($assignment, 'added volume to test group successfully');
Genome::Sys->create_directory(join('/', $volume->mount_path, $group->subdirectory));

my $archive_assignment = Genome::Disk::Assignment->create(
    group => $group,
    volume => $archive_volume
);
ok($archive_assignment, 'added archive volume to test group successfully');
Genome::Sys->create_directory(join('/', $archive_volume->mount_path, $group->subdirectory));

# Make test allocation
my $allocation_path = tempdir(
    "allocation_test_1_XXXXXX",
    CLEANUP => 1,
    UNLINK => 1,
    DIR => $test_dir,
);

# Make test allocation
my $shouldnt_allocation_path = tempdir(
    "allocation_test_2_XXXXXX",
    CLEANUP => 1,
    UNLINK => 1,
    DIR => $test_dir,
);

my $should_allocation = Genome::Disk::Allocation->create(
    disk_group_name => $group->disk_group_name,
    allocation_path => $allocation_path,
    kilobytes_requested => (1024**2)+1,
    owner_class_name => 'UR::Value',
    owner_id => 'test',
    mount_path => $volume->mount_path,
    archive_after_time => time()-10000
);
ok($should_allocation, 'created test allocation');
system("touch " . $should_allocation->absolute_path . "/a.out");

# Override these methods so archive/active volume linking works for our test volumes
no warnings 'redefine';
*Genome::Disk::Volume::archive_volume_prefix = sub { return $archive_volume->mount_path };
*Genome::Disk::Volume::active_volume_prefix = sub { return $volume->mount_path };
use warnings;


# Make another allocation
$shouldnt_allocation_path = tempdir(
    "allocation_test_3_XXXXXX",
    CLEANUP => 1,
    UNLINK => 1,
);
my $shouldnt_allocation = Genome::Disk::Allocation->create(
    disk_group_name => $group->disk_group_name,
    allocation_path => $shouldnt_allocation_path,
    kilobytes_requested => 100,
    owner_class_name => 'UR::Value',
    owner_id => 'test',
    mount_path => $volume->mount_path,
    archive_after_time => time()+10000
);
ok($shouldnt_allocation, 'created test allocation that should not get archived');
system("touch " . $shouldnt_allocation->absolute_path . "/a.out");


# Create command object and execute it
my $cmd = Genome::Disk::Command::Allocation::ArchiveExpired->create(
  disk_group_name=>$group->disk_group_name,
  archive_time => Date::Format::time2str(UR::Context->date_template, time()),
);
ok($cmd, 'created archive expired command');
ok($cmd->execute, 'successfully executed archive expired command');
is($should_allocation->volume->id, $archive_volume->id, 'allocation moved to archive volume');
is($shouldnt_allocation->volume->id, $volume->id, 'shouldnt be archived allocation has not moved to archive volume');

ok($should_allocation->is_archived, 'should be archived allocation is now archived');
ok(!$shouldnt_allocation->is_archived, 'shouldnt be archived allocation is not archived');

done_testing();


1;
