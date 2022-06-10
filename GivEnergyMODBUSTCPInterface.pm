package GivEnergyMODBUSInterface;
use strict;
use warnings;

use Device::Modbus::TCP::Client;
use IO::Socket::INET;
use Carp qw(croak);
use Readonly;

my $address = '192.168.2.165';
Readonly my $DEFAULT_PORT = 8899;
my $port = $DEFAULT_PORT;
my $timeout = 2;


my $socket = IO::Socket::INET->new(PeerHost => $address, PeerPort => $port, Proto => 'tcp', Timeout => $timeout );
if (!$socket) {
    croak("Failed to connect to MODBUS TCP Client on ${address}:${port}");
} else {

    # See https://github.com/dewet22/givenergy-modbus/blob/0bf9b34e58b944fd7e6f0576912e8f41b15b14d8/givenergy_modbus/framer.py for frame details.

    my $tid = 'YY';
    my $pid = "\x00"."\x01";
#    my $len = 0;
    my $uid = "\x01";
#    my $fid = "\x01"; # Heartbeat
    my $fid = "\x02"; # Transparent

    # Transparent frame!
    my $serial = 'SA2211G232';
#    my $pad = ?;
    my $addr = "\x11"; # Inverter
    my $func = "\x03"; # Read holding registers
#    my $func = "\x04"; # Read input registers
    my $data = '';
#    my $crc = ?; # CRC for a request is calculated using the function id, base register and step count, but it is unclear how a response CRC is calculated or should be verified.

    my $FRAME_HEAD = '>HHHBB';
#    my $FRAME_HEAD_SIZE = ?;


    my $inner_frame = ' ';
    my $len = len($inner_frame)+2;
    my $mbap_header = $FRAME_HEAD.$tid.$pid.$len.$pid.$fid;
#    my $mbap_header = self.FRAME_HEAD, 0x5959, 0x1, len($inner_frame) + 2, 0x1, message.main_function_code);

}


my $client = Device::Modbus::TCP::Client->new( host => $address, port => $port, timeout => $timeout );
if (!$client) {
    croak('Failed to create object!');
} elsif ($client->connected()) {
    croak("Connected to MODBUS TCP Client on ${address}:${port}");
} else {
    croak("Failed to connect to MODBUS TCP Client on ${address}:${port}");
}

#my $req = $client->read_holding_registers( unit => 3, address => 2, quantity => 1 );


$client->disconnect();

1;