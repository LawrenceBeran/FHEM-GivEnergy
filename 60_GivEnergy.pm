package main;
use strict;
use warnings;

use GivEnergyInterface;
use JSON;
use Readonly;

# Common logging levels..
Readonly my $LL_FATAL = 0;
Readonly my $LL_ERROR = 1;
Readonly my $LL_WARNING = 2;
Readonly my $LL_INFO = 3;
Readonly my $LL_DEBUG = 4;
Readonly my $LL_TRACE = 5;

# DEFINE myGivEnergy GivEnergy <token>

sub _getGivEnergyInterface($) {
    my ($hash) = @_;

    if (!defined($hash->{GivEnergy}{interface})) {
        Log($LL_INFO, '_getGivEnergyInterface: Creating new GivEnergyInterface object!');

        $hash->{GivEnergy}{interface} = GivEnergyInterface->new(token => $hash->{token});
    }
    return $hash->{GivEnergy}{interface};
}

sub GivEnergy_Initialize($) {
	my ($hash) = @_;

	Log($LL_TRACE, 'GivEnergy_Initialize: enter');

	# Provider
	$hash->{Clients}  = 'GivEnergy_.*';
	my %mc = (
		'1:GivEnergy_ProductInverter' => '^GivEnergy_ProductInverter',    # The start of the parent Dispatch & inverter Parse message must contain this string to match this inverter.
#		'2:HiveHome_Action' => '^HiveHome_Action',
#		'3:HiveHome_Product' => '^HiveHome_Product',
	);
	$hash->{MatchList} = \%mc;
    $hash->{WriteFn}  = 'GivEnergy_Write';

	#Consumer
	$hash->{DefFn}    = 'GivEnergy_Define';
	$hash->{UndefFn}  = 'GivEnergy_Undefine';

    $hash->{GivEnergy}{client} = undef;
    $hash->{helper}->{sendQueue} = [];

	Log($LL_TRACE, 'GivEnergy_Initialize: exit');
	return undef;
}

sub GivEnergy_Define($$) {
	my ($hash, $def) = @_;

	Log($LL_TRACE, 'GivEnergy_Define: enter');

	my ($name, $type, $token) = split(' ', $def);

    # TODO: perhaps the token should be put into a file for use...

	$hash->{STATE} = 'Disconnected';
	$hash->{INTERVAL} = 60;
	$hash->{NAME} = $name;
	$hash->{token} = $token;

	$modules{GivEnergy}{defptr} = $hash;

	# Interface used by the hubs children to communicate with the physical hub
	$hash->{InitNode} = \&GivEnergy_UpdateNodes;

	# Create a timer to get object details
	InternalTimer(gettimeofday()+1, 'GivEnergy_GetUpdate', $hash, 0);

    $attr{$name}{room}  = 'GivEnergy';

	Log($LL_TRACE, 'GivEnergy_Define: exit');

	return undef;
}

sub GivEnergy_Undefine($$) {
	my ($hash, $def) = @_;

	Log($LL_TRACE, 'GivEnergy_Undefine: enter');

	RemoveInternalTimer($hash);

	$hash->{GivEnergy}{SessionId} = undef;

	Log($LL_TRACE, 'GivEnergy_Undefine: exit');

	return undef;
}

sub GivEnergy_GetUpdate() {
	my ($hash) = @_;

	Log($LL_TRACE, 'GivEnergy_GetUpdate: enter');

    GivEnergy_UpdateNodes($hash, undef);

	InternalTimer(gettimeofday()+$hash->{INTERVAL}, 'GivEnergy_GetUpdate', $hash, 0);

	Log($LL_TRACE, 'GivEnergy_GetUpdate: exit');

	return undef;
}

############################################################################

sub _givEnergy_ProcessSiteProductInverter($$$$) {
	my ($hash, $givenergy_client, $site_id, $product_inverter) = @_;
	Log($LL_TRACE, '_givEnergy_ProcessSiteProductInverter: entry');

    my $system_data = $givenergy_client->getLatestSystemData($product_inverter->{serial});
    my $meter_data = $givenergy_client->getLatestMeterData($product_inverter->{serial});

    if (!$systemData) {
        Log($LL_ERROR, '_givEnergy_ProcessSiteProductInverter: Failed to get latest system data for inverter - '.$product_inverter->{serial});
    } else {
        $product_inverter->{systemData} = $system_data->{data};
    }

    if (!$meterData) {
        Log($LL_ERROR, '_givEnergy_ProcessSiteProductInverter: Failed to get latest meter data for inverter - '.$product_inverter->{serial});
    } else {
        $product_inverter->{meterData} = $meter_data->{data};
    }

    my $product_inverter_string = encode_json($product_inverter);
    Dispatch($hash, 'GivEnergy_ProductInverter,'.$product_inverter->{serial}.",${site_id},${product_inverter_string}", undef);

	Log($LL_TRACE, '_givEnergy_ProcessSiteProductInverter: exit');
}

sub _givEnergy_ProcessSite($$$) {
	my ($hash, $givenergy_client, $site) = @_;
	Log($LL_TRACE, '_givEnergy_ProcessSite: entry');

    # TODO: Do something with the site information!
#        print("\nSite:          ".$site->{id}."\n");
#        print('  Name:        '.$site->{name}."\n");
#        print('  Country:     '.$site->{country}."\n");
#        print('  Timezone:    '.$site->{timezone}."\n");
#        print('  Latitude:    '.$site->{latitude}."\n");
#        print('  Longitude:   '.$site->{longitude}."\n");
#        print('  Account:     '.$site->{account}."\n");
#        print('  DateCreated: '.$site->{date_created}."\n");


    foreach my $product (@{$site->{products}}) {
        if (lc($product->{name}) eq 'inverters') {
            foreach my $product_inverter (@{$product->{data}}) {
                _givEnergy_ProcessSiteProductInverter($hash, $givenergy_client, $site->{id}, $product_inverter);
            }
        } else {
            # TODO: what else could we get here, something else to process!
        }
    }

	Log($LL_TRACE, '_givEnergy_ProcessSite: exit');
}

sub _givEnergy_ProcessSites($$) {
	my ($hash, $givenergy_client) = @_;

	Log($LL_TRACE, '_givEnergy_ProcessSites: entry');

    # Get all sites
    my $resp_sites = $givenergy_client->getSites();
    if (!$resp_sites) {
        Log($LL_ERROR, '_givEnergy_ProcessSites: Failed to get sites!');
    } else {
        foreach my $site (@{$resp_sites->{data}}) {
            _givEnergy_ProcessSite($hash, $givenergy_client, $site);
        }
    }

	Log($LL_TRACE, '_givEnergy_ProcessSites: exit');
}

############################################################################
# This function updates the internal and reading values on the hive objects.
############################################################################

sub GivEnergy_UpdateNodes() {
	my ($hash, $from_define) = @_;

	Log($LL_TRACE, 'GivEnergy_UpdateNodes: enter');

	my $presence = 'ABSENT';

    my $givenergy_client = _getGivEnergyInterface($hash);
    if (!defined($givenergy_client)) {
		Log($LL_ERROR, 'GivEnergy_UpdateNodes: Failed to create GivEnergy interface!');
		$hash->{STATE} = 'Disconnected';
    } else {
		Log($LL_DEBUG, 'GivEnergy_UpdateNodes: Succesfully created GivEnergy interface');
		$hash->{STATE} = 'Connected';

        # TODO: Maybe get account information to show against the base node!
#        $givenergy_client->

        _givEnergy_ProcessSites($hash, $givenergy_client);

    }

	Log($LL_TRACE, '"GivEnergy_UpdateNodes: exit');
}

sub GivEnergy_Write($$$) {
    my ($hash, @args) = @_;

    # Extract the device command details from the args array.
    my $shash = shift(@args);
    my $cmd = shift(@args);

    my $name = $shash->{NAME};

    Log($LL_TRACE, 'GivEnergy_Write: enter');
    Log($LL_DEBUG, "GivEnergy_Write: ${name} ${cmd} ".int(@args));

    my $ret = undef;


    Log($LL_TRACE, 'GivEnergy_Write: exit');

    return $ret;
}


sub _verifyWriteCommandArgs($$$$) {
    my ($hash, $shash, $cmd, @args) = @_;

    my $ret = undef;


    return $ret;
}

1;


