
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use HTML::HashTable ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.


$VERSION = $VERSION = 0.60;

require 5.005;

package HTML::HashTable;

require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(tablify);

use strict;

=head1 NAME

C<HTML::HashTable> - Create an HTML table from a Perl hash

=head1 SYNOPSIS

    use HTML::HashTable;
    print tablify({
        BORDER      => 0, 
	DATA        => $myhashref, 
	SORTBY      => 'key', 
	ORDER       => 'desc',
	TABLE_ID    => 'my_table',
	WITH_HEADER => 1
    });

=head1 DESCRIPTION

This module takes an arbitrary Perl hash and presents it as an HTML
table.  The hash can contain anything you want -- scalar data, 
arrayrefs, hashrefs, whatever.  Yes, this means you can use a tied
hash if you wish.

The HTML produced is nicely formatted and indented, suitable for
human editing and manipulation.

Some options are provided with the tablify() function to allow you
to specify whether you wish to have a border or not, whether you
wish your table to be sorted by key or value (but note that sorting
by value gives almost meaningless results if your values are 
references, as in a deeply nested Perl data structure), and define
some basic html structural elements for the html.

The options given to the tablify() function are:

=over 4

=item C<BORDER>

True or false depending on whether you want your table to have a
border.  Defaults to false (0).

=item C<DATA>

Reference to your hash

=item C<SORTBY>

Either 'key' or 'value' depending on how you want your data sorted.
Note that sorting by value is more or less meaningless if your
values are references (as in a deeply nested data structure).  Defaults
to "key".

=item C<ORDER>

Either 'asc' or 'desc' depending on whether you want your sorting to
be in ascending or descending order.  Defaults to "asc".

=item C<TABLE_ID>

Adds an ID value to the table element - useful for styling and other
funky DOM trickery.

If there are multiple tables (due to nesting), then they will be labled
thus: C<string>, C<string.1>, C<string.2>, C<string.3>, ....

(Reminder: the C<id> must be unique within the whole DOM.)

=item C<WITH_HEADER>

True or false, defaults false (0). This creates a header row
using the first block of data, and puts them in a C<thead> section.

=back

=head2 Example call, and css

Given the data:

	$data = {
		grunt => {
					b => "c",
					d => [ qw( foo bar baz ) ],
			},
		snort => [ qw( wombat roo cocky ) ],
		blurf => "g",
	};

the call:

    my $table = tablify({BORDER      => 0,
                     DATA        => $data,
                     TABLE_ID    => 'kiz',
                     WITH_HEADER => 1,
                     });

will produce the following html:

	<table id='kiz' >
		<thead>
			<tr>
				<th>blurf</th>
				<th>g</th>
			</tr>
		</thead>
		<tbody>
			<tr>
				<td>grunt</td>
				<td>
					<table id='kiz.1' >
						<tbody>
							<tr>
								<td>grunt</td>
								<td></td>
							</tr>
							<tr>
								<td>snort</td>
								<td></td>
							</tr>
						</tbody>
					</table>
				</td>
			</tr>
			<tr>
				<td>snort</td>
				<td>wombat</td>
				<td>roo</td>
				<td>cocky</td>
			</tr>
		</tbody>
	</table>

.... and one could use css such as:
    
    // use [id=kiz] to get an exact match
    table[id=kiz] th {
        font-weight: bold;
    }
    table[id=kiz] tbody tr:nth-child(even) {
        background-color:yellow;
    }

    // use [id^=kiz\.] to get a starts with match
    table[id^=kiz\.] {
        border: 1px solid black;
    }
    table[id^=kiz\.] tbody tr:nth-child(even) {
        background-color:green;
    }

to style it.

=cut

sub tablify {
	$HTML::HashTable::output = '';
	$HTML::HashTable::depth = 0;
	$HTML::HashTable::global_row_count = 0;
	$HTML::HashTable::id_index = 0;
	my $tsref = shift;
        $tsref->{SORTBY}      ||= "key";
        $tsref->{ORDER}       ||= "asc";
        $tsref->{BORDER}      ||= 0;
		$tsref->{TABLE_ID}    ||= '';
		$tsref->{WITH_HEADER} ||= 0;
    @HTML::HashTable::keys = sort { 
		if ($tsref->{SORTBY} eq "value") {
			if ($tsref->{ORDER} eq 'asc') {
				${$tsref->{DATA}}{$a} cmp ${$tsref->{DATA}}{$b};
			} else { 
				${$tsref->{DATA}}{$b} cmp ${$tsref->{DATA}}{$a};
			}
		} else {
			if ($tsref->{ORDER} eq 'asc') {
				$a cmp $b;
			} else {
				$b cmp $a;
			}
		}
	} keys %{$tsref->{DATA}};
	make_table($tsref);
	return $HTML::HashTable::output;
}

#
# This subroutine does most of the work by recursing through the
# hash supplied.  We look to see whether the value of any hash
# item is a scalar, an arrayref or a hashref, and act accordingly.
# Recursion's so rare in Perl... this is *fun*
#

sub recurse_through {
	my $tsref = shift;
	my $thingy = shift; 
	if (ref($thingy) eq 'ARRAY') {
		foreach (@$thingy) {
			recurse_through($tsref, $_);
		}
	} elsif (ref($thingy) eq 'HASH') {
		my $newref = {%$tsref};
		$newref->{DATA} = $thingy;
		open_cell($tsref->{WITH_HEADER});
		make_table($newref);
		close_cell($HTML::HashTable::depth, $tsref->{WITH_HEADER});
	} else {	# plain old scalar data
		open_cell($tsref->{WITH_HEADER});
		$HTML::HashTable::output .= $thingy;
		close_cell(0, $tsref->{WITH_HEADER});
	}
}

sub open_table {
	my $tsref = shift;
	$HTML::HashTable::output .= "\n";
	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
	$HTML::HashTable::output .= '<table';
	$HTML::HashTable::output .= $tsref->{BORDER} ? ' border=1 ' : ' border=0 ' ;
	if ($tsref->{TABLE_ID}) {
		if ($HTML::HashTable::id_index) {
			$HTML::HashTable::output .= " id='" . $tsref->{TABLE_ID} . '.' . $HTML::HashTable::id_index . "' ";
		} else {
            $HTML::HashTable::output .= " id='" . $tsref->{TABLE_ID} . "' ";
		}
		$HTML::HashTable::id_index++;
	}
	
	$HTML::HashTable::output .= ">\n";
	$HTML::HashTable::depth++;
    if ($tsref->{WITH_HEADER}) {
        make_header($tsref);
        $tsref->{WITH_HEADER} = 0;
    }
	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
    $HTML::HashTable::output .= "<tbody>\n";
	$HTML::HashTable::depth++;
}

sub close_table {
	$HTML::HashTable::depth--;
	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
    $HTML::HashTable::output .= "</tbody>\n";
	$HTML::HashTable::depth--;
	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
	$HTML::HashTable::output .= "</table>\n";
}

sub make_header {
	my $tsref = shift;
    $HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
    $HTML::HashTable::output .= "<thead>\n";
	$HTML::HashTable::depth++;
    my $key = shift @HTML::HashTable::keys;
    open_row();
    open_cell($tsref->{WITH_HEADER});
	$HTML::HashTable::output .= $key;
	close_cell(0, $tsref->{WITH_HEADER});
	recurse_through($tsref, ${$tsref->{DATA}}{$key});
	close_row();
	$HTML::HashTable::depth--;

	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
    $HTML::HashTable::output .= "</thead>\n";

}

sub open_row {
	$HTML::HashTable::global_row_count++;
	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
	$HTML::HashTable::output .= "<tr>\n";
	$HTML::HashTable::depth++;
}

sub close_row {
	$HTML::HashTable::depth--;
	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
	$HTML::HashTable::output .= "</tr>\n";
}

sub open_cell {
	my $with_header = shift;
 	$HTML::HashTable::output .= "\t" x $HTML::HashTable::depth;
	$HTML::HashTable::output .= $with_header ? "<th>" : "<td>";
	$HTML::HashTable::depth++;
}

sub close_cell {
	my $d = shift;
	my $with_header = shift;
 	$d-- if $d;
	$HTML::HashTable::output .= "\t" x ($d);
	$HTML::HashTable::output .= $with_header ? "</th>\n" : "</td>\n";
	$HTML::HashTable::depth--;
}
	
sub make_table {
	my $tsref = shift;
	open_table($tsref);
	foreach my $key (@HTML::HashTable::keys) {
		open_row;
		open_cell($tsref->{WITH_HEADER});
		$HTML::HashTable::output .= $key;
		close_cell(0, $tsref->{WITH_HEADER});
		recurse_through($tsref, ${$tsref->{DATA}}{$key});
		close_row;
	}
	close_table;
}	




=head1 AUTHOR

Kirrily "Skud" Robert <skud@cpan.org>

=head1 SEE ALSO

L<perl>.

=cut
