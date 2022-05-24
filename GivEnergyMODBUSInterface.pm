package GivEnergyMODBUSInterface;
use strict;
use warnings;

use Device::Modbus::TCP::Client;
use Carp qw(croak);
use Readonly;

my $address = '192.168.2.165';
my $port = undef;
my $timeout = 2;



my $client = Device::Modbus::TCP::Client->new( host => $address, port => $port, timeout => $timeout );
if (!$client || !$client->connected) {
    croak("Failed to connect to MODBUS TCP Client on ${address}:${port}");
}

#my $req = $client->read_holding_registers( unit => 3, address => 2, quantity => 1 );


$client->disconnect();

1;