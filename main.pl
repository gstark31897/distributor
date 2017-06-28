use Mojolicious::Lite;
use Mojo::IOLoop;
use Mojo::Server::Daemon;
use MongoDB;
use Digest::SHA3 qw(sha3_256_hex);
use Data::Dumper;
use strict;

my $port   = shift;
my $daemon = Mojo::Server::Daemon->new(
    app    => app,
    listen => ["http://*:$port"]
);

my $client = MongoDB->connect('mongodb://localhost');
my $keyval = $client->ns("distributor:$port.keyval");
my $meta   = $client->ns("distributor:$port.meta");
my $nodes  = $client->ns("distributor:$port.nodes");

sub find_min_max_count {
    my $max_cur = $keyval->find()->sort( { 'hash' => -1 } )->limit(1);
    my $min_cur = $keyval->find()->sort( { 'hash' => 1 } )->limit(1);
    my $max     = "";
    my $min     = "";
    my $count   = $keyval->count();

    $max = '';
    while ( my $item = $max_cur->next ) {
        $max = $item->{'hash'};
    }
    $min = '';
    while ( my $item = $min_cur->next ) {
        $min = $item->{'hash'};
    }

    update_meta( 'min',   $min );
    update_meta( 'max',   $max );
    update_meta( 'count', $count );
}

sub update_meta {
    my $key   = shift;
    my $value = shift;
    my $item  = $meta->find_one( { key => "$key" } );
    if ($item) {
        $meta->update_many( { key => "$key" },
            { '$set' => { value => "$value" } } );
    }
    else {
        $meta->insert_one( { key => "$key", value => "$value" } );
    }
}

sub get_meta {
    my $key = shift;
    my $cur = $meta->find( { key => "$key" } );
    while ( my $item = $cur->next ) {
        my $value = $item->{'value'};
        print "value: $value\n";
        return $value;
    }
}

find_min_max_count();
update_meta( 'port', $port );

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
    my $time  = time;

    my $node = $nodes->find_one( { host => "$addr:$port" } );
    if ($node) {
        $nodes->update_many(
            { host => "$addr:$port" },
            {
                host  => "$addr:$port",
                min   => "$min",
                max   => "$max",
                count => "$count",
                limit => "$limit",
                time  => "$time"
            }
        );
    }
    else {
        $nodes->insert_one(
            {
                host  => "$addr:$port",
                min   => "$min",
                max   => "$max",
                count => "$count",
                limit => "$limit",
                time  => "$time"
            }
        );
    }

    # TODO store these values
    # TODO make a daemon that sends these requests out randomly
    # TODO make the min and max actually work
    my $my_min   = get_meta('min');
    my $my_max   = get_meta('max');
    my $my_count = get_meta('count');
    $c->render(
        json => {
            port  => $port,
            min   => "$my_min",
            max   => "$my_max",
            count => "$my_count",
            limit => 100
        }
    );
};

$daemon->run;
