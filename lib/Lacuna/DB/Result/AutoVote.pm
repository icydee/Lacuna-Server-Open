package Lacuna::DB::Result::AutoVote;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::DB::Result';

__PACKAGE__->load_components('DynamicSubclass');
__PACKAGE__->table('auto_vote');
__PACKAGE__->add_columns(
    empire_id       => { data_type => 'int',        size => 11, is_nullable => 0 },
    station_id      => { data_type => 'int',        size => 11, is_nullable => 0 },
    type            => { data_type => 'varchar',    size => 30, is_nullable => 0 },
); 

__PACKAGE__->typecast_map(type => {
    seize           => 'Lacuna::DB::Result::AutoVote::Seize',
    construction    => 'Lacuna::DB::Result::AutoVote::Construction',
    rename          => 'Lacuna::DB::Result::AutoVote::Rename',
    bfg             => 'Lacuna::DB::Result::AutoVote::BFG',
    members_only    => 'Lacuna::DB::Result::AutoVote::MembersOnly',
});

__PACKAGE__->belongs_to('station',  'Lacuna::DB::Result::Map::Body',    'station_id');
__PACKAGE__->belongs_to('empire',   'Lacuna::DB::Result::Empire',       'empire_id');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
