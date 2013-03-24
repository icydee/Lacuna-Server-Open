package Lacuna::DB::Result::AutoVote::MembersOnly;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::DB::Result::AutoVote';

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

