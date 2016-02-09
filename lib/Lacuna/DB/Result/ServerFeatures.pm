package Lacuna::DB::Result::ServerFeatures;

use Moose;
use utf8;

extends 'Lacuna::DB::Result';

__PACKAGE__->load_components('Core');

__PACKAGE__->table('server_features');
__PACKAGE__->add_columns(
    name        => { data_type => 'varchar',  size => 32,     is_nullable => 0 },
    who         => { data_type => 'varchar',  size => 32,     is_nullable => 0 },
    description => { data_type => 'varchar',  size => 32,     is_nullable => 0 },
);
__PACKAGE__->set_primary_key('id');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
