package Trog::SQLite;

use strict;
use warnings;

no warnings 'experimental';
use feature qw{signatures};

use POSIX qw{floor};

use DBI;
use DBD::SQLite;
use File::Slurper();
use List::Util qw{any};

=head1 Name

Bogo::SQLite - Abstracts the boilerpain away!

=head1 SYNOPSIS

    my $dbh = Bogo::SQLite::dbh("my_schema.sql", "my_sqlite3.db");
    ...

=head1 FUNCTIONS

Everything in this module throws when something goes wrong.

=head2 dbh

Get you a database handle with fkeys turned on, and schema consistency enforced.
Caches the handle past the first call.

Be careful when first calling, the standard fork-safety concerns with sqlite apply

=cut

my $dbh = {};
# Ensure the db schema is OK, and give us a handle
sub dbh {
    my ($schema,$dbname) = @_;
    return $dbh->{$schema} if $dbh->{$schema};
    my $qq = File::Slurper::read_text($schema);
    my $db = DBI->connect("dbi:SQLite:dbname=$dbname","","");
    $db->{sqlite_allow_multiple_statements} = 1;
    $db->do($qq) or die "Could not ensure database consistency";
    $db->{sqlite_allow_multiple_statements} = 0;
    $dbh->{$schema} = $db;

    # Turn on fkeys
    $db->do("PRAGMA foreign_keys = ON") or die "Could not enable foreign keys";
    return $db;
}

=head2 bulk_insert(DBI $dbh, STRING $table, ARRAYREF $keys, STRING $action='IGNORE', MIXED @values)

Insert the values into specified table corresponding to the provided keys.
Values must be repeating tuples corresponding to the values. Example:

    my $keys   = [qw{A B C}];
    my @values = qw{1 2 3 4 5 6 7 8 9};

Essentially works around the 999 named param limit and executes by re-using prepared statements.
This results in a quick insert/update of lots of data, such as when building an index or importing data.

For the vast majority of in-practice usage, this will be swatting flies with an elephant gun.
That said, it should always do the job correctly and quickly, even for trivial datasets.

If you don't put fkeys in place (or simply turn them off),
you can use REPLACE as your action to do upserts without causing destructive consequences.
It's less code than writing an ON CONFLICT UPDATE clause, and faster.

Batch your values to whatever is appropriate given your available heap.

=cut


sub bulk_insert ($dbh, $table, $keys, $ACTION='IGNORE', @values) {
    die "unsupported insert action $ACTION" unless any { $ACTION eq $_ } qw{ROLLBACK ABORT FAIL IGNORE REPLACE};

    die "keys must be nonempty ARRAYREF" unless ref $keys eq 'ARRAY' && @$keys;
    die "#Values must be a multiple of #keys" if @values % @$keys;

    my ($smt,$query) = ('','');
    while (@values) {
        #Must have even multiple of #keys, so floor divide and chop remainder
        my $nkeys = scalar(@$keys);
        my $limit = floor( 999 / $nkeys );
        $limit = $limit - ( $limit % $nkeys);
        $smt = '' if scalar(@values) < $limit;
        my @params = splice(@values,0,$limit);
        if (!$smt) {
            my @value_tuples;
            my @huh = map { '?' } @params;
            while (@huh) {
                push(@value_tuples, "(".join(',',(splice(@huh,0,$nkeys))).")");
            }
            $query = "INSERT OR $ACTION INTO $table (".join(',',@$keys).") VALUES ".join(',',@value_tuples);
            $smt = $dbh->prepare($query);
        }
        $smt->execute(@params);
    }
}

1;
