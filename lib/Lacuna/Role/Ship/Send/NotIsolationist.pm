package Lacuna::Role::Ship::Send::NotIsolationist;

use strict;
use Moose::Role;

after can_send_to_target => sub {
    my ($self, $target) = @_;
    confess [1013, sprintf('%s is an isolationist empire, and must be left alone.',$target->empire->name)] if $target->empire->is_isolationist;
};

1;
