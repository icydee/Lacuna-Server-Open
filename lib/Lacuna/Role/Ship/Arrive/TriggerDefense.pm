package Lacuna::Role::Ship::Arrive::TriggerDefense;

use strict;
use Moose::Role;

after handle_arrival_procedures => sub {
    my ($self) = @_;
    
    # no defense at stars
    return unless $self->foreign_body_id;
    
    # no defense unless inhabited
    my $body_attacked = $self->foreign_body;
    return unless $body_attacked->empire_id;    
    
    # no defense against self
    return if $body_attacked->empire_id == $self->body->empire_id;
    
    # set last attack status
    Lacuna->cache->set('last_attacked_by',$body_attacked->id, $self->body->id, 60 * 60 * 24 * 30);
        
    # get SAWs
    my $saws = $body_attacked->get_buildings_of_class('Lacuna::DB::Result::Building::SAW');
    
    # if there are SAWs lets duke it out
    while (my $saw = $saws->next) {
        next if $saw->level < 1;
        next if $saw->efficiency < 1;
        next if $saw->is_working;
        my $combat = ($saw->level * 1000) * ( $saw->efficiency / 100 );
        $saw->spend_efficiency( int( $self->combat / 100 ) );
        $saw->start_work({}, 60 * 5);
        $saw->update;
        $self->damage_in_combat($combat);
    }

    # get defensive ships
    my $defense_ships = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search(
        { body_id => $self->foreign_body_id, type => { in => [qw(fighter drone sweeper)]}, task=>'Docked'},
        );
    
    # if there are defensive ships let's duke it out
    while (my $defender = $defense_ships->next) {
        my $damage = $defender->combat;
        if ($defender->type eq 'drone') {
            $defender->delete;
        }
        else {
            $defender->combat( $defender->combat - $damage );
            if ($defender->combat < 1) {
                $defender->delete;
            }
            else {
                $defender->send(target => $body_attacked->star);
            }
        }
        $self->damage_in_combat($damage);
    }
};


sub damage_in_combat {
    my ($self, $damage) = @_;
    $self->combat( $self->combat - $damage );
    return unless $self->combat < 1;
    my $body_attacked = $self->foreign_body;
    $self->body->empire->send_predefined_message(
        tags        => ['Alert'],
        filename    => 'ship_shot_down.txt',
        params      => [$self->type_formatted, $body_attacked->x, $body_attacked->y, $body_attacked->name, $self->body->id, $self->body->name],
    );
    $body_attacked->empire->send_predefined_message(
        tags        => ['Alert'],
        filename    => 'we_shot_down_a_ship.txt',
        params      => [$self->type_formatted, $body_attacked->id, $body_attacked->name, $self->body->empire_id, $self->body->empire->name],
    );
    $body_attacked->add_news(20, sprintf('An amateur astronomer witnessed an explosion in the sky today over %s.',$body_attacked->name));
    $self->delete;
    confess [-1]
}

1;
