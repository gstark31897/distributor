use Mojolicious::Lite;
use Mojo::IOLoop;
use Mojo::Server::Daemon;
use MongoDB;
use Digest::SHA3 qw(sha3_256_hex);
use Data::Dumper;
use strict;

my $port   = 2000;
my $daemon = Mojo::Server::Daemon->new(
    app    => app,
    listen => ["http://*:$port"]
);

my $client = MongoDB->connect('mongodb://localhost');
my $keyval = $client->ns('distributor.keyval');
my $meta   = $client->ns('distributor.meta');

get '/data/:key' => sub {
    my $c    = shift;
    my $key  = $c->param('key');
    my $data = $keyval->find_one( { key => "$key" } );
    print "$data\n";
    $c->render( json => $data );
};

post '/data/:key' => sub {
    my $c     = shift;
    my $key   = $c->param('key');
    my $value = $c->req->json->{'value'};
    my $hash  = sha3_256_hex($value);
    my $data  = $keyval->find_one( { key => "$key" } );
    if ($data) {
        $keyval->update_many( { key => "$key" },
            { '$set' => { value => "$value", hash => "$hash" } } );
    }
    else {
        my $result = $keyval->insert_one(
            { key => "$key", value => "$value", hash => "$hash" } );
    }
    $c->render( json => { hash => "$hash" } );
};

post '/meta' => sub {
    my $c     = shift;
    my $addr  = $c->req->env->{REMOTE_ADDR};
    my $port  = $c->req->json->{'port'};
    my $min   = $c->req->json->{'min'};
    my $max   = $c->req->json->{'max'};
    my $count = $c->req->json->{'count'};
    my $limit = $c->req->json->{'limit'};

    # TODO store these values
    # TODO make a daemon that sends these requests out randomly
    # TODO make the min and max actually work
    $c->render(
        json => {
            port => $port,
            min =>
'0000000000000000000000000000000000000000000000000000000000000000',
            max =>
'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            count => 0,
            limit => 100
        }
    );
};

$daemon->run;
