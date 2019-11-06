use Test::More tests => 14;

BEGIN: { use_ok('HTML::HashTable'); }

use HTML::HashTable;

my $testhash = {
    grunt => {
                b => "c",
                d => [ qw( foo bar baz ) ],
           },
    snort => [ qw( wombat roo cocky ) ],
    blurf => "g",
};

ok(tablify({ DATA => $testhash }), "Tablify testhash");
my $html = tablify({ DATA => $testhash });
like($html, qr/table.*tbody.*blurf.*grunt.*snort/s, "output looks roughly right");
like($html, qr/border=0/s, "defaults to no border");
unlike($html, qr/id=/s, "defaults to no id");
unlike($html, qr/thead/s, "defaults to no header row");
like(tablify({ DATA => $testhash, ORDER => 'desc'}), qr/snort.*grunt.*blurf/s, "sorting backwards works");
like(tablify({ DATA => $testhash, BORDER => 1}), qr/border=1/s, "with border");
like(tablify({ DATA => $testhash, BORDER => 0}), qr/border=0/s, "no border");
like(tablify({ DATA => $testhash, TABLE_ID => 'kiz'}), qr/id='kiz'/s, "with table ID");
like(tablify({ DATA => $testhash, WITH_HEADER => 1}), qr/thead.*th/s, "Adds a header");
$html = tablify({ DATA => $testhash, BORDER => 1, TABLE_ID => 'kiz', WITH_HEADER => 1});
like($html, qr/table.*border=1.*id='kiz'.*thead.*th.*tbody/s, "Multiple params seem to work OK");
my @ids = ();
while ($html =~ /id='([^']+)'/g) {
    push @ids, $1;
}
is(scalar @ids, 2, "Have two ids in the output");
isnt($ids[0], $ids[1], "ids are different");
print "HTML output, with all flags set, is:\n$html\n";