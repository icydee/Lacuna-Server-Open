package Lacuna::DB::Result::Office;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::DB::Result';

__PACKAGE__->load_components('DynamicSubclass');
__PACKAGE__->table('office');
__PACKAGE__->add_columns(
    empire_id       => { data_type => 'int',        size => 11, is_nullable => 0 },
    alliance_id     => { data_type => 'int',        size => 11, is_nullable => 0 },
    station_id      => { data_type => 'int',        size => 11, is_nullable => 0 },
    type            => { data_type => 'varchar',    size => 30, is_nullable => 0 },
); 

__PACKAGE__->typecast_map(type => {
    construction        => 'Lacuna::DB::Result::Office::Construction',
    public_relations    => 'Lacuna::DB::Result::Office::PublicRelations',
    membership          => 'Lacuna::DB::Result::Office::Membership',
    members_rights      => 'Lacuna::DB::Result::Office::MembersRights',
    war                 => 'Lacuna::DB::Result::Office::War',
});

__PACKAGE__->belongs_to('station',  'Lacuna::DB::Result::Map::Body',    'station_id');
__PACKAGE__->belongs_to('empire',   'Lacuna::DB::Result::Empire',       'empire_id');
__PACKAGE__->belongs_to('alliance', 'Lacuna::DB::Result::Alliance',     'alliance_id');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
