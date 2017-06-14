use MongoDB;
use Digest::SHA3 qw(sha3_256_hex);
use Mojolicious::Lite;
use Data::Dumper;
use strict;

my $client = MongoDB->connect('mongodb://localhost');
my $keyval = $client->ns('distributor.keyval');
my $meta = $client->ns('distributor.meta');

get '/data/:key' => sub {
    my $c = shift;
    my $key = $c->param('key');
    my $data = $keyval->find_one({ key => "$key" });
    print "$data\n";
    $c->render(json => $data)
};

post '/data/:key' => sub {
    my $c = shift;
    my $key = $c->param('key');
    my $value = $c->req->json->{'value'};
    my $hash = sha3_256_hex($value);
    my $data = $keyval->find_one({ key => "$key" });
    if ($data) {
        $keyval->update_many({ key => "$key" }, { '$set' => {value => "$value", hash => "$hash"}});
    } else {
        my $result = $keyval->insert_one({ key => "$key", value => "$value", hash => "$hash" });
    }
    $c->render(json => {hash => "$hash"})
};

get '/meta/range' => sub {
    my $c = shift;
    $c->render(json => {min => '0000000000000000000000000000000000000000000000000000000000000000', max => 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'});
};

app->start;
