package Lacuna::DB::Result::Ships::HulkFast;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::DB::Result::Ships';


use constant prereq                 => { class=> 'Lacuna::DB::Result::Building::Trade',  level => 28 };
# Figure out how to also add Prop Level 30 to prereq
use constant base_food_cost         => 15000;
use constant base_water_cost        => 30000;
use constant base_energy_cost       => 500000;
use constant base_ore_cost          => 1000000;
use constant base_time_cost         => 43200;
use constant base_waste_cost        => 100000;
use constant base_speed             => 750;
use constant base_stealth           => 0;
use constant base_hold_size         => 10000;
use constant base_berth_size         => 25;
use constant pilotable              => 1;
use constant build_tags             => [qw(Trade Mining)];

with "Lacuna::Role::Ship::Send::UsePush";
with "Lacuna::Role::Ship::Arrive::CargoExchange";


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
