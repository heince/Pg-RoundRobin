#
#===============================================================================
#
#         FILE: RoundRobin.pm6
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Heince Kurniawan (), heince.kurniawan@itgroupinc.asia
# ORGANIZATION: IT Group Indonesia
#      VERSION: 1.0
#      CREATED: 02/17/18 17:12:23
#     REVISION: ---
#===============================================================================
use v6;
unit class Pg::RoundRobin;
use DBIish;
use Pg::RoundRobin::Host;

my $host = Pg::RoundRobin::Host::Candidate.new();
has Array @.dbservers           is required;
has Bool  $.recheck             = False;
has Bool  $.prefer_secondary    = False; # prefer secondary node to do read only

method init()
{
    $host.prefer_secondary = self.prefer_secondary;

    for @.dbservers -> $dbserver
    {
        $host.set_candidate($dbserver.Hash);
    }
}

method primary()
{
    $host.get_primary();
}

method secondary()
{
    $host.get_secondary();
}

method add_primary_counter()
{
    $host.add_primary_counter();
}

method for_testing()
{
    return True;
}

=begin pod
=head1 SYNOPSIS
    use v6;
    use Pg::RoundRobin;

    my $rr = Pg::RoundRobin.new(
                prefer_secondary => True, # if this set to True, primary node will not be used for read only
                dbservers =>
                (
                    [ :host<127.0.0.1>, :port<5432>, :database<heince>, :user<heince> ],
                    [ :host<127.0.0.1>, :port<5433>, :database<heince>, :user<heince> ],
                    [ :host<127.0.0.1>, :port<5434>, :database<heince>, :user<heince> ]
                )
             );
    $rr.init;
    
    # below will do round robin read only connection to all secondary node 
    # if there's node fail it will try to the next possible secondary node 
    OUTER: while True
    {
        my $dbh = $rr.secondary();
        next OUTER if $dbh eqv (Any);
        my $sth = $dbh.prepare("select * from test");
        $sth.execute();

        my @rows = $sth.allrows();
        $sth.finish();
        $dbh.dispose();

        for @rows -> ($id, $name)
        {
            say "id: $id, name: $name";
        }

        sleep 1;
    }

=head1 DESCRIPTION
This is a simple implementation of round robin failover connection on top of DBIish.
It will scan and group primary and secondary node accordingly at init.
=head1 DBIish CLASSES and ROLES
=head2 Pg::RoundRobin
The C<Pg::RoundRobin> class exists mainly to provide the F<init> method,
which acts as a constructor for database connections.
F<primary> will return DB Handle for primary node
F<secondary> will return DB Handle for secondary node
=end pod
