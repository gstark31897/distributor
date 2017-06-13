use MongoDB;
use Digest::SHA3 qw(sha3_256_hex);
use Mojolicious::Lite;
use Data::Dumper;
use strict;

my $client = MongoDB->connect('mongodb://localhost');
my $keyval = $client->ns('distributor.keyval');
my $meta = $client->ns('distributor.meta');

get '/:key' => sub {
    my $c = shift;
    my $key = $c->param('key');
    my $data = $keyval->find_one({ key => "$key" });
    print "$data\n";
    $c->render(json => $data)
};

post '/:key' => sub {
    my $c = shift;
    my $key = $c->param('key');
    my $value = $c->req->json->{'value'};
    my $hash = sha3_256_hex($value);
    my $result = $keyval->insert_one({ key => "$key", value => "$value", hash => "$hash" });
    $c->render(json => {hash => "$hash"})
};

app->start;

