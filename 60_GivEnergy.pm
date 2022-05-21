package main;
use strict;
use warnings;

use GivEnergyInterface;
use JSON;

# DEFINE myGivEnergy GivEnergy <token>

sub _getGivEnergyInterface($) {
    my ($hash) = @_;

    if (!defined($hash->{GivEnergy}{interface})) {
        Log(3, "_getGivEnergyInterface: Creating new GivEnergyInterface object!");

        $hash->{GivEnergy}{interface} = GivEnergyInterface->new(token => $hash->{token});
    }
    return $hash->{GivEnergy}{interface};
}

sub GivEnergy_Initialize($) {
	my ($hash) = @_;

	Log(1, "GivEnergy_Initialize: enter");

	# Provider
	$hash->{Clients}  = "GivEnergy_.*";
	my %mc = (
		"1:GivEnergy_ProductInverter" => "^GivEnergy_ProductInverter",		# The start of the parent Dispatch & inverter Parse message must contain this string to match this inverter.
#		"2:HiveHome_Action" => "^HiveHome_Action",		
#		"3:HiveHome_Product" => "^HiveHome_Product",		
	);
	$hash->{MatchList} = \%mc;
    $hash->{WriteFn}  = "GivEnergy_Write";

	#Consumer
	$hash->{DefFn}    = "GivEnergy_Define";
	$hash->{UndefFn}  = "GivEnergy_Undefine";

    $hash->{GivEnergy}{client} = undef;
    $hash->{helper}->{sendQueue} = [];

	Log(1, "GivEnergy_Initialize: exit");
	return undef;
}

sub GivEnergy_Define($$) {
	my ($hash, $def) = @_;

	Log(1, "GivEnergy_Define: enter");

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
	InternalTimer(gettimeofday()+1, "GivEnergy_GetUpdate", $hash, 0);

    $attr{$name}{room}  = 'GivEnergy';

	Log(1, "GivEnergy_Define: exit");

	return undef;
}

sub GivEnergy_Undefine($$) {
	my ($hash, $def) = @_;

	Log(1, "GivEnergy_Undefine: enter");

	RemoveInternalTimer($hash);

	$hash->{GivEnergy}{SessionId} = undef;

	Log(1, "GivEnergy_Undefine: exit");

	return undef;
}

sub GivEnergy_GetUpdate() {
	my ($hash) = @_;

	Log(1, "GivEnergy_GetUpdate: enter");

    GivEnergy_UpdateNodes($hash, undef);

	InternalTimer(gettimeofday()+$hash->{INTERVAL}, "GivEnergy_GetUpdate", $hash, 0);

	Log(1, "GivEnergy_GetUpdate: exit");

	return undef;
}

############################################################################

sub _givEnergy_ProcessSiteProductInverter($$$$) {
	my ($hash, $givEnergyClient, $siteId, $productInverter) = @_;
	Log(1, "_givEnergy_ProcessSiteProductInverter: entry");

    my $systemData = $givEnergyClient->getLatestSystemData($productInverter->{serial});
    my $meterData = $givEnergyClient->getLatestMeterData($productInverter->{serial});

    if (!$systemData) {
        Log(1, "_givEnergy_ProcessSiteProductInverter: Failed to get latest system data for inverter - ".$productInverter->{serial});
    } else {
        $productInverter->{systemData} = $systemData->{data};
    }

    if (!$meterData) {
        Log(1, "_givEnergy_ProcessSiteProductInverter: Failed to get latest meter data for inverter - ".$productInverter->{serial});
    } else {
        $productInverter->{meterData} = $meterData->{data};
    }

    my $productInverterString = encode_json($productInverter);
    Dispatch($hash, "GivEnergy_ProductInverter,".$productInverter->{serial}.",".$siteId.",".$productInverterString, undef);

	Log(1, "_givEnergy_ProcessSiteProductInverter: exit");
}

sub _givEnergy_ProcessSite($$$) {
	my ($hash, $givEnergyClient, $site) = @_;
	Log(1, "_givEnergy_ProcessSite: entry");

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
            foreach my $productInverter (@{$product->{data}}) {
                _givEnergy_ProcessSiteProductInverter($hash, $givEnergyClient, $site->{id}, $productInverter);
            }
        } else {
            # TODO: what else could we get here, something else to process!
        }
    }

	Log(1, "_givEnergy_ProcessSite: exit");
}

sub _givEnergy_ProcessSites($$) {
	my ($hash, $givEnergyClient) = @_;

	Log(1, "_givEnergy_ProcessSites: entry");

    # Get all sites
    my $respSites = $givEnergyClient->getSites();
    if (!$respSites) {
        Log(1, "_givEnergy_ProcessSites: Failed to get sites!");
    } else {
        foreach my $site (@{$respSites->{data}}) {
            _givEnergy_ProcessSite($hash, $givEnergyClient, $site);
        }
    }

	Log(1, "_givEnergy_ProcessSites: exit");
}

############################################################################
# This function updates the internal and reading values on the hive objects.
############################################################################

sub GivEnergy_UpdateNodes() {
	my ($hash, $fromDefine) = @_;

	Log(1, "GivEnergy_UpdateNodes: enter");

	my $presence = "ABSENT";

    my $givEnergyClient = _getGivEnergyInterface($hash);
    if (!defined($givEnergyClient)) {
		Log(1, "GivEnergy_UpdateNodes: Failed to create GivEnergy interface!");
		$hash->{STATE} = 'Disconnected';
    } else {
		Log(4, "GivEnergy_UpdateNodes: Succesfully created GivEnergy interface");
		$hash->{STATE} = "Connected";

        # TODO: Maybe get account information to show against the base node!
#        $givEnergyClient->

        _givEnergy_ProcessSites($hash, $givEnergyClient);

    }

	Log(1, "GivEnergy_UpdateNodes: exit");
}

sub GivEnergy_Write($$$) {
    my ($hash, @args) = @_;

    # Extract the device command details from the args array.
    my $shash = shift(@args);
    my $cmd = shift(@args);    

    my $name = $shash->{NAME};

    Log(1, "GivEnergy_Write: enter");
    Log(4, "GivEnergy_Write: ${name} ${cmd} ".int(@args));

    my $ret = undef;


    Log(1, "GivEnergy_Write: exit");

    return $ret;
}


sub _verifyWriteCommandArgs($$$$) {
    my ($hash, $shash, $cmd, @args) = @_;

    my $ret = undef;


    return $ret;
}

1;


