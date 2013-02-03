package Lacuna::RPC::Building::Trade;

use Moose;
use feature "switch";
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::RPC::Building';
use Guard;
use List::Util qw(first);
use Lacuna::Constants qw(FOOD_TYPES ORE_TYPES SHIP_WASTE_TYPES SHIP_TRADE_TYPES);

with 'Lacuna::Role::TraderRpc','Lacuna::Role::Fleet::Trade','Lacuna::Role::Navigation';

sub app_url {
    return '/trade';
}

sub model_class {
    return 'Lacuna::DB::Result::Building::Trade';
}

sub accept_from_market {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            trade_id        => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
    my $trade_id    = $args->{trade_id};

    if (not $trade_id) {
        confess [1002, 'You have not specified a trade to accept.'];
    }
    my $cache = Lacuna->cache;
    if (! $cache->add('trade_lock', $trade_id, 1, 5)) {
        confess [1013, 'Another buyer has placed an offer on this trade. Please wait a few moments and try again.'];
    }
    my $guard = guard {
        $cache->delete('trade_lock',$trade_id);
    };

    if ($building->level < 1) {
        confess [1013, 'You cannot use a trade ministry that has not yet been built.'];
    }

    $empire->current_session->check_captcha;

    my $trade = $building->market->find($trade_id);
    if (not defined $trade) {
        confess [1002, 'Could not find that trade. Perhaps it has already been accepted.',$trade_id];
    }
    my $offer_fleet = Lacuna->db->resultset('Fleet')->find($trade->fleet_id);
    if (not defined $offer_fleet) {
        $trade->withdraw;
        confess [1009, 'Trade no longer available.'];
    }

    my $body = $building->body;
    if ($empire->essentia < $trade->ask) {
        confess [1011, 'You need at least '.$trade->ask.' essentia to make this trade.']
    }

    $self->check_payload_fleet_id($trade->payload->{fleets}, $body);

    $guard->cancel;

    $empire->spend_essentia($trade->ask, 'Trade Price', 0, $trade->body->empire->id, $trade->body->empire->name )->update;
    $trade->body->empire->add_essentia($trade->ask, 'Trade Income', 0, $empire->id, $empire->name)->update;
    
    $offer_fleet->send(
        target  => $body,
        payload => $trade->payload,
    );
    
    $trade->body->empire->send_predefined_message(
        tags        => ['Trade','Alert'],
        filename    => 'trade_accepted.txt',
        params      => [join("; ",@{$trade->format_description_of_payload}), $trade->ask.' essentia', $empire->id, $empire->name],
    );
    $trade->delete;

    return {
        status      => $self->format_status($empire, $building->body),
    };
}


sub add_fleet_to_supply_duty {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            fleet_id        => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
    my $fleet_id    = $args->{fleet_id};
    my $quantity    = $args->{quantity} || 1;

    if (not defined $building) {
        confess [1002, "Building not found."];
    }
    my $fleet = Lacune->db->resultset('Fleet')->find($fleet_id);
    if (not defined $fleet) {
        confess [1002, "Fleet not found."];
    }
    if ($fleet->task ne 'Docked') {
        confess [1009, "That fleet is not available."];
    }
    if ($fleet->hold_size <= 0) {
        confess [1009, 'That fleet has no cargo hold.'];
    }
    if ($fleet->body_id != $building->body_id) {
        confess [1013, "You can't manage a fleet that is not yours."];
    }
    if (not first {$fleet->type eq $_} (SHIP_TRADE_TYPES)) {
        confess [1009, 'You can only add transport ships to a supply chain.'];
    }
    my $max_berth = $building->body->max_berth;

    if ($fleet->berth_level > $max_berth) {
        confess [1009, "You don't have a high enough berth for this fleet."];
    }
    $fleet = $fleet->split($quantity);
    
    $building->add_fleet_to_supply_duty($fleet);
    return {
        status  =>$self->format_status($empire, $building->body),
    };
}

sub add_fleet_to_waste_duty {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            fleet_id        => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
    my $fleet_id    = $args->{fleet_id};
    my $quantity    = $args->{quantity} || 1;

    if (not defined $building) {
        confess [1002, "Building not found."];
    }
    my $fleet = Lacune->db->resultset('Fleet')->find($fleet_id);
    if (not defined $fleet) {
        confess [1002, "Fleet not found."];
    }
    if ($fleet->task ne 'Docked') {
        confess [1009, "That fleet is not available."];
    }
    if ($fleet->hold_size <= 0) {
        confess [1009, 'That fleet has no cargo hold.'];
    }
    if ($fleet->body_id != $building->body_id) {
        confess [1013, "You can't manage a fleet that is not yours."];
    }
    if ($fleet->type !~ m/^scow/) {
        confess [1009, 'You can only add scows to a supply chain.'];
    }
    my $max_berth = $building->body->max_berth;

    if ($fleet->berth_level > $max_berth) {
        confess [1009, "You don't have a high enough berth for this fleet."];
    }
    $fleet = $fleet->split($quantity);
    $building->add_fleet_to_waste_duty($fleet);
    return {
        status  =>$self->format_status($empire, $building->body),
    };
}

sub add_to_market {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            offer           => shift,
            ask             => shift,
            options         => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
    if ($building->level < 1) {
        confess [1013, 'You cannot use a trade ministry that has not yet been built.'];
    }
    my $cache = Lacuna->cache;
    if (not $cache->add('trade_add_lock', $building->id, 1, 5)) {
        confess [1013, 'You have a trade setup in progress.  Please wait a few moments and try again.'];
    }
    my $guard = guard {
        $cache->delete('trade_add_lock',$building->id);
    };
    my $trade = $building->add_to_market($args->{offer}, $args->{ask}, $args->{options});
    return {
        trade_id    => $trade->id,
        status      => $self->format_status($empire, $building->body),
    };
}

sub create_supply_chain {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            target_id       => shift,
            resource_type   => shift,
            resource_hour   => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
    if (not defined $building) {
        confess [1002, "You must specify a building."];
    }
    if ($building->level < 1) {
        confess [1013, 'You cannot use a trade ministry that has not yet been built.'];
    }
    # 'target_id' over-rides 'target'
    if ($args->{target_id}) {
        $args->{target} = { body_id => $args->{target_id}};
    }
    my $body        = $building->body;
    my $max_chains  = $building->level * 3;
    if ($body->out_supply_chains->count >= $max_chains) {
        confess [1002, "You cannot create any more supply chains outgoing from this planet."];
    }

    my $resource_hour = $args->{resource_hour};
    if (not defined $resource_hour) {
        confess [1002, "You must specify an amount for resource_hour."];
    }
    if ($resource_hour < 0) {
        confess [1002, "Resource per hour must be positive or zero."];
    }
    my $resource_type = $args->{resource_hour};
    if (not first {$resource_type eq $_} (FOOD_TYPES, ORE_TYPES, qw(water waste energy))) {
        confess [1002, "That is not a valid resource_type."];
    }
    my $target = $self->find_target($args->{target});

    if ($body->id == $target->id) {
        confess [1002, "You can't set up a supply chain to yourself."];
    }

    # Target must be own empire or an allies
    if ($target->empire_id != $empire->id) {
        if ($target->alliance_id != $empire->alliance_id) {
            confess [1002, "You can only target one of your own or an allies colony or Space Station."];
        }
    }

    my $chain       = $building->supply_chains->create({
        planet_id           => $body->id,
        building_id         => $building->id,
        target_id           => $target->id,
        resource_hour       => $resource_hour,
        resource_type       => $resource_type,
        percent_transferred => 0,
    });
    unless ($chain) {
        confess [1002, "Cannot create a supply chain."];
    }
    $building->recalc_supply_production;

    return $self->view_supply_chains($args->{session_id}, $building->id);
}


#------------------------------------------------------------------------------







sub get_trade_ships {
    my ($self, $session_id, $building_id, $target_id) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    my $target = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($target_id) if $target_id;
    my @ships;
    my $ships = $building->trade_ships;
    while (my $ship = $ships->next) {

        push @ships, $ship->get_status($target);
    }
    return {
        status      => $self->format_status($empire, $building->body),
        ships       => \@ships,
    };
}

sub remove_supply_ship_from_fleet {
    my ($self, $session_id, $building_id, $ship_id) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    unless (defined $building) {
        confess [1002, "Building not found."];
    }

    my $ship = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->find($ship_id);
    unless (defined $ship) {
        confess [1002, "Ship not found."];
    }
    unless ($ship->task eq 'Supply Chain') {
        confess [1009, "That ship is not in a Supply Chain."];
    }
    unless ($ship->body_id eq $building->body_id) {
        confess [1013, "You can't manage a ship that is not yours."];
    }

    my $supply_chain = $building->supply_chains->search({},{rows => 1})->single;
    if (defined $supply_chain) {
        my $from = $supply_chain->target;
        $building->send_supply_ship_home($from, $ship);
    }
    else {
        $ship->land->update;
    }
    return {
        status  => $self->format_status($empire, $building->body),
    };
}

sub remove_waste_ship_from_fleet {
    my ($self, $session_id, $building_id, $ship_id) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    unless (defined $building) {
        confess [1002, "Building not found."];
    }

    my $ship = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->find($ship_id);
    unless (defined $ship) {
        confess [1002, "Ship not found."];
    }
    unless ($ship->task eq 'Waste Chain') {
        confess [1009, "That ship is not in a Waste Chain."];
    }
    unless ($ship->body_id eq $building->body_id) {
        confess [1013, "You can't manage a ship that is not yours."];
    }

    my $waste_chain = $building->waste_chains->search({},{rows => 1})->single;
    if (defined $waste_chain) {
        my $from = $building->body->star;
        $building->send_waste_ship_home($from, $ship);
    }
    else {
        $ship->land->update;
    }
    return {
        status  => $self->format_status($empire, $building->body),
    };
}

sub get_supply_ships {
    my ($self, $session_id, $building_id) = @_;

    my $empire      = $self->get_empire_by_session($session_id);
    my $building    = $self->get_building($empire, $building_id);

    my @ships;
    my $ships       = $building->all_supply_ships;
    while (my $ship = $ships->next) {
        push @ships, $ship->get_status;
    }
    return {
        status      => $self->format_status($empire, $building->body),
        ships       => \@ships,
    };
}

sub get_waste_ships {
    my ($self, $session_id, $building_id) = @_;
    my $empire      = $self->get_empire_by_session($session_id);
    my $building    = $self->get_building($empire, $building_id);
    my $body        = $building->body;
    # get the local star
    my $target      = Lacuna->db->resultset('Lacuna::DB::Result::Map::Star')->find($body->star_id);
    my @ships;
    my $ships       = $building->all_waste_ships;
    while (my $ship = $ships->next) {
        push @ships, $ship->get_status($target);
    }
    return {
        status      => $self->format_status($empire, $building->body),
        ships       => \@ships,
    };
}

sub view_supply_chains {
    my ($self, $session_id, $building_id) = @_;
    my $empire      = $self->get_empire_by_session($session_id);
    my $building    = $self->get_building($empire, $building_id);
    unless ($building) {
        confess [1002, "Cannot find that building."];
    }

    my $max_chains = $building->level * 3;
    my @supply_chains;
    my $chains      = $building->supply_chains;
    while (my $chain = $chains->next) {
        push @supply_chains, $chain->get_status;
    }
    return {
        status          => $self->format_status($empire, $building->body),
        supply_chains  => \@supply_chains,
        max_supply_chains => $max_chains,
    };
}


sub view_waste_chains {
    my ($self, $session_id, $building_id) = @_;
    my $empire      = $self->get_empire_by_session($session_id);
    my $building    = $self->get_building($empire, $building_id);
    unless ($building) {
        confess [1002, "Cannot find that building."];
    }
    my @waste_chains;
    my $chains      = $building->waste_chains;
    while (my $waste_push = $chains->next) {
        push @waste_chains, $waste_push->get_status;
    }
    return {
        status          => $self->format_status($empire, $building->body),
        waste_chain     => \@waste_chains,
    };
}

sub delete_supply_chain {
    my ($self, $session_id, $building_id, $supply_chain_id) = @_;

    my $empire      = $self->get_empire_by_session($session_id);
    my $building    = $self->get_building($empire, $building_id);
    unless ($building) {
        confess [1002, "Cannot find that building."];
    }

    my $chain = Lacuna->db->resultset('Lacuna::DB::Result::SupplyChain')->find($supply_chain_id);
    if ($chain) {
        $building->remove_supply_chain($chain);
    }
    return $self->view_supply_chains($session_id, $building_id);    
}

sub update_supply_chain {
    my ($self, $session_id, $building_id, $supply_chain_id, $resource_type, $resource_hour) = @_;
    my $empire      = $self->get_empire_by_session($session_id);
    my $building    = $self->get_building($empire, $building_id);
    unless ($building) {
        confess [1002, "Cannot find that building."];
    }
    my $body        = $building->body;
    unless ($supply_chain_id) {
        confess [1002, "You must specify a supply chain id."];
    }
    unless (defined $resource_hour) {
        confess [1002, "You must specify an amount for resource_hour."];
    }
    unless ($resource_hour >= 0) {
        confess [1002, "Resource per Hour must be positive or zero."];
    }
    unless (first {$resource_type eq $_} (FOOD_TYPES, ORE_TYPES, qw(water waste energy))) {
        confess [1002, "That is not a valid resource_type."];
    }
    my $chain       = $building->supply_chains->find($supply_chain_id);
    unless ($chain) {
        confess [1002, "That Supply Chain does not exist on this planet."];
    }
    $chain->resource_hour(int($resource_hour));
    $chain->resource_type($resource_type);
    $chain->update;
    $building->recalc_supply_production;

    return $self->view_supply_chains($session_id, $building_id);
}

sub update_waste_chain {
    my ($self, $session_id, $building_id, $waste_chain_id, $waste_hour) = @_;
    my $empire      = $self->get_empire_by_session($session_id);
    my $building    = $self->get_building($empire, $building_id);
    unless ($building) {
        confess [1002, "Cannot find that building."];
    }
    my $body        = $building->body;
    unless ($waste_chain_id) {
        confess [1002, "You must specify a waste chain id."];
    }
    unless (defined $waste_hour) {
        confess [1002, "You must specify an amount for waste_hour."];
    }
    unless ($waste_hour >= 0) {
        confess [1002, "Waste per Hour must be positive or zero."];
    }

    my $chain       = $building->waste_chains->find($waste_chain_id);
    unless ($chain) {
        confess [1002, "That Waste Chain does not exist on this planet."];
    }
    $chain->waste_hour(int($waste_hour));
    $chain->update;
    $building->recalc_waste_production;

    return $self->view_waste_chains($session_id, $building_id);
}


sub push_items {
    my ($self, $session_id, $building_id, $target_id, $items, $options) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    confess [1013, 'You cannot use a trade ministry that has not yet been built.'] unless $building->level > 0;
    my $cache = Lacuna->cache;
    if (! $cache->add('trade_add_lock', $building_id, 1, 5)) {
        confess [1013, 'You have a trade setup in progress.  Please wait a few moments and try again.'];
    }
    my $guard = guard {
        $cache->delete('trade_add_lock',$building_id);
    };
    unless ($target_id) {
        confess [1002, "You must specify a target body id."];
    }
    my $target = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($target_id);
    if (not defined $target) {
        confess [1002, 'The target body you specified could not be found.'];
    }
    if ($target->class eq 'Lacuna::DB::Result::Map::Body::Planet::Station') {
        my $planet = $building->body;
        if ($target->alliance_id == $empire->alliance_id) {
            # You can push anything to your Alliance's Space Stations
        }
        elsif ($target->in_jurisdiction($planet)) {
            # Allowed to push food, ore, water and energy only to SS that control your star
            foreach my $item (@{$items}) {
                given($item->{type}) {
                    when([qw(waste glyph plan prisoner ship)]) {
                        confess [1010, "You cannot push $item->{type} to that space station."];
                    }
                }
            }
        }
        else {
            confess [1010, 'You cannot push items to that space station.'];
        }
    }
    else {
        # You can push anything to your own planets
        unless ($target->empire_id == $empire->id) {
            confess [1010, 'You cannot push items to a planet that is not your own.'];
        }
    }
    my $ship = $building->push_items($target, $items, $options);
    return {
        status      => $self->format_status($empire, $building->body),
        ship        => $ship->get_status,
    };
}

sub withdraw_from_market {
    my ($self, $session_id, $building_id, $trade_id) = @_;
    unless ($trade_id) {
        confess [1002, 'You have not specified a trade to withdraw.'];
    }
    my $cache = Lacuna->cache;
    if (! $cache->add('trade_lock', $trade_id, 1, 5)) {
        confess [1013, 'A buyer has placed an offer on this trade. Please wait a few moments and try again.'];
    }
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    my $trade = $building->market->find($trade_id);
    unless (defined $trade) {
        confess [1002, 'Could not find that trade. Perhaps it has already been accepted.'];
    }
    $trade->withdraw($building->body);
    return {
        status      => $self->format_status($empire, $building->body),
    };
}

sub accept_from_market {
    my ($self, $session_id, $building_id, $trade_id) = @_;
    unless ($trade_id) {
        confess [1002, 'You have not specified a trade to accept.'];
    }
    my $cache = Lacuna->cache;
    if (! $cache->add('trade_lock', $trade_id, 1, 5)) {
        confess [1013, 'Another buyer has placed an offer on this trade. Please wait a few moments and try again.'];
    }
    my $guard = guard {
        $cache->delete('trade_lock',$trade_id);
    };

    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    confess [1013, 'You cannot use a trade ministry that has not yet been built.'] unless $building->level > 0;

    $empire->current_session->check_captcha;

    my $trade = $building->market->find($trade_id);
    unless (defined $trade) {
        confess [1002, 'Could not find that trade. Perhaps it has already been accepted.',$trade_id];
    }
    my $offer_ship = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->find($trade->ship_id);
    unless (defined $offer_ship) {
        $trade->withdraw;
        confess [1009, 'Trade no longer available.'];
    }

    my $body = $building->body;
    unless ($empire->essentia >= $trade->ask) {
        confess [1011, 'You need at least '.$trade->ask.' essentia to make this trade.']
    }

    $self->check_payload_ships_id($trade->payload->{ships}, $body);

    $guard->cancel;

    $empire->transfer_essentia({
        amount      => $trade->ask,
        from_reason => 'Trade Price',
        to_empire   => $trade->body->empire,
        to_reason   => 'Trade Income',
    })->update;

    $offer_ship->send(
        target  => $body,
        payload => $trade->payload,
    );
    
    $trade->body->empire->send_predefined_message(
        tags        => ['Trade','Alert'],
        filename    => 'trade_accepted.txt',
        params      => [join("; ",@{$trade->format_description_of_payload}), $trade->ask.' essentia', $empire->id, $empire->name],
    );
    $trade->delete;

    return {
        status      => $self->format_status($empire, $building->body),
    };
}

sub add_to_market {
    my ($self, $session_id, $building_id, $offer, $ask, $options) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    confess [1013, 'You cannot use a trade ministry that has not yet been built.'] unless $building->level > 0;
    my $cache = Lacuna->cache;
    if (! $cache->add('trade_add_lock', $building_id, 1, 5)) {
        confess [1013, 'You have a trade setup in progress.  Please wait a few moments and try again.'];
    }
    my $guard = guard {
        $cache->delete('trade_add_lock',$building_id);
    };
    my $trade = $building->add_to_market($offer, $ask, $options);
    return {
        trade_id    => $trade->id,
        status      => $self->format_status($empire, $building->body),
    };
}

__PACKAGE__->register_rpc_method_names(qw(
    accept_from_market
    add_fleet_to_supply_duty
    add_fleet_to_waste_duty
    add_to_market
    create_supply_chain
    delete_supply_chain
    get_glyph_summary
    get_glyphs
    get_plan_summary
    get_plans
    get_ship_summary
    get_ships
    get_stored_resources
    get_supply_ships
    get_prisoners
    get_trade_ships
    get_waste_ships
    push_items
    remove_supply_ship_from_fleet
    remove_waste_ship_from_fleet
    report_abuse
    update_supply_chains
    update_waste_chains
    view_market
    view_my_market
    view_supply_chains 
    view_waste_chains 
    withdraw_from_market 
));

no Moose;
__PACKAGE__->meta->make_immutable;

