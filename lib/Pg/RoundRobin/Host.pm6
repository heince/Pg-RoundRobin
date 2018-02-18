#
#===============================================================================
#
#         FILE: Host.pm6
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Heince Kurniawan (), heince.kurniawan@itgroupinc.asia
# ORGANIZATION: IT Group Indonesia
#      VERSION: 1.0
#      CREATED: 02/17/18 16:51:16
#     REVISION: ---
#===============================================================================
use v6;

unit module Pg::RoundRobin::Host;
use DBIish;

class Candidate 
{
    has Bool    $.available         = False;
    has Array   @.primary           is rw;
    has Array   @.secondary         is rw;
    has Bool    $.prefer_secondary  is rw = False; # prefer secondary node to do read only 
    has Bool    $.primary_error     is rw = False;
    has Bool    $.secondary_error   is rw = False;

    my Int $primary_counter     = 0;
    my Int $secondary_counter   = 0;

    method add_primary_counter()
    {
        $primary_counter == self.primary.elems - 1 ?? ($primary_counter = 0) !! $primary_counter++ ;
    }

    method add_secondary_counter()
    {
        $secondary_counter == self.secondary.elems - 1 ?? ($secondary_counter = 0) !! $secondary_counter++ ;
    }

    method get_secondary()
    {
        self.secondary_error = False;
        self.add_secondary_counter();

        if self.prefer_secondary == False
        {
            push self.secondary, |self.primary;
        }

        if self.secondary.elems > 0
        {
            my $dbh = DBIish.connect('Pg', |self.secondary[$secondary_counter].Hash);
            if $dbh eqv (Any)
            {
                self.get_secondary();
            }

            CATCH
            {
                default
                {
                    self.secondary_error = True;
                    say "Exception: $_";
                }
            }

            if self.secondary_error == False
            {
                self.secondary_error = False;
                return $dbh;
            }
        }
        else
        {
            die "secondary node not available";
        }
    }

    method get_primary()
    {
        self.primary_error = False;
        self.add_primary_counter();

        if self.primary.elems > 0
        {
            my $dbh = DBIish.connect('Pg', |self.primary[$primary_counter].Hash);
            if $dbh eqv (Any)
            {
                self.get_primary();
            }

            CATCH
            {
                default
                {
                    self.primary_error = True;
                    say "Exception: $_";
                }
            }

            if self.primary_error == False
            {
                self.primary_error = False;
                return $dbh;
            }
        }
        else
        {
            die "primary node not available";
        }
    }

    method list()
    {
        if self.primary.elems > 0
        {
            for self.primary -> $primary
            {
                FIRST 
                { say "primary: " }
                say $primary.Hash;
            }
        }
        else
        {
            say "No Primary Server";
        }

        if self.secondary.elems > 0
        {
            for self.secondary -> $secondary
            {
                FIRST { say "secondary: " };
                say "\t$secondary";
            }
        }
        else
        {
            say "No Secondary Server";
        }
    }

    method set_candidate(%con)
    {
        my Bool $error = False;

        my $dbh = DBIish.connect('Pg', |%con);
        CATCH
        {
            default
            {
                $error = True;
                say "skiping: $_";
            }
        }

        if $error == False
        {
            if self!is_secondary($dbh)
            {
                push self.secondary, [%con];
            }
            else
            {
                push self.primary, [%con];
            }
        }

        $dbh.dispose();
    }

    method !is_secondary($dbh) of Bool
    {
        my $sth     = $dbh.prepare('select pg_is_in_recovery()');
        $sth.execute();
        my @result  = $sth.row();
        $sth.finish();

        if @result[0] eq 't'
        {
            return True;
        }
        else
        {
            return False;
        }
    }
}

