use 5.010;
use strict;
use lib '/data/Lacuna-Server/lib';
use Lacuna::DB;
use Lacuna;
use Lacuna::Util qw(randint format_date);
use Getopt::Long;
use AnyEvent;
$|=1;
our $quiet;
our $randomize;
GetOptions(
    'quiet'         => \$quiet,
    'randomize'         => \$randomize,
);



out('Started');
my $start = time;

if ($randomize) {
    sleep randint(0, 60*60*18); # attack anytime in the next 18 hours.
}


out('Loading DB');
our $db = Lacuna->db;
our $ai = Lacuna::AI::Trelvestian->new;

my $config = Lacuna->config;

out('Looping through colonies...');
my $colonies = $ai->empire->planets;
my @attacks;
while (my $attacking_colony = $colonies->next) {
    out('Found colony to attack from named '.$attacking_colony->name);
    out('Finding target body to attack...');
    my $target_colony = $attacking_colony->get_last_attacked_by;
    my @ships = qw(sweeper snark snark2 snark3);
    out('Attacking '.$target_colony->name);
    push @attacks, $ai->start_attack($attacking_colony, $target_colony, [shift @ships]);
}

out("Waiting on attacks...");
foreach my $attack (@attacks) {
    $attack->recv if defined $attack;
}

my $finish = time;
out('Finished');
out((($finish - $start)/60)." minutes have elapsed");




###############
## SUBROUTINES
###############


sub out {
    my $message = shift;
    unless ($quiet) {
        say format_date(DateTime->now), " ", $message;
    }
}


