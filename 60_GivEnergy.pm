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
		"1:GivEnergy_Inverter" => "^GivEnergy_Inverter",		# The start of the parent Dispatch & inverter Parse message must contain this string to match this inverter.
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
	
#    if ($init_done) 
    {
        $attr{$name}{room}  = 'GivEnergy';
#        $attr{$name}{devStateIcon} = 'Connected:10px-kreis-gruen@green Disconnected:message_attention@orange .*:message_attention@red';
#        $attr{$name}{icon} = 'rc_HOME';
    }

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

sub _givEnergy_ProcessSiteProductInverter($$$) {
	my ($hash, $givEnergyClient, $productInverter) = @_;
	Log(1, "_givEnergy_ProcessSiteProductInverter: entry");

#    print("\n  Inverter:          ".$productInverter->{serial}."\n");
#    print('    Status:          '.$productInverter->{status}."\n");
#    print('    Model:           '.$productInverter->{info}->{model}."\n");
#    print('    Battery type:    '.$productInverter->{info}->{battery_type}."\n");
#    print('    Warranty:        '.$productInverter->{warranty}->{type}.", expiry - ".$productInverter->{warranty}->{expiry_date}."\n");
#    print('    Commission date: '.$productInverter->{commission_date}."\n");
#    print('    Last online:     '.$productInverter->{last_online}."\n");
#    print('    Last updated:    '.$productInverter->{last_updated}."\n");
#    print("    Firmware versions:\n");
#    foreach my $firmware (keys %{$productInverter->{firmware_version}}) {
#        print('      '.$firmware.':            '.$productInverter->{firmware_version}->{$firmware}."\n");
#    }
    # TODO: connections!    

    my $systemData = $givEnergyClient->getLatestSystemData($productInverter->{serial});
    if (!$systemData) {
        Log(1, "_givEnergy_ProcessSiteProductInverter: Failed to get latest system data for inverter - ".$productInverter->{serial});
    } else {
        my $data = $systemData->{data};

#        print('      Time:               '.$data->{time}."\n");
#        print('      Consumption:        '.$data->{consumption}."\n");


        my $dataInverter = $data->{inverter};
#        print("      Inverter:\n");
#        print('        Power:            '.$dataInverter->{power}."\n");
#        print('        Temperature:      '.$dataInverter->{temperature}."\n");
#        print('        EPS power:        '.$dataInverter->{eps_power}."\n");
#        print('        Output frequency: '.$dataInverter->{output_frequency}."\n");
#        print('        Output voltage:   '.$dataInverter->{output_voltage}."\n");

        my $dataGrid = $data->{grid};
        if ($dataGrid) {
#           print("      Grid:\n");
#           print('        Power:            '.$dataGrid->{power}."\n");
#           print('        Current:          '.$dataGrid->{current}."\n");
#           print('        Frequency:        '.$dataGrid->{frequency}."\n");
#           print('        Voltage:          '.$dataGrid->{voltage}."\n");
        }

        my $dataBattery = $data->{battery};
        if ($dataBattery) {
#           print("      Battery:\n");
#           print('        Power:            '.$dataBattery->{power}."\n");
#           print('        Temperature:      '.$dataBattery->{temperature}."\n");
#           print('        Percentage:       '.$dataBattery->{percent}."\n");
        }

        my $dataSolar = $data->{solar};
        if ($dataSolar) {
#           print("      Solar:\n");
#           print("        Power:            ".$dataSolar->{power}."\n");

            foreach my $array (@{$dataSolar->{arrays}}) {
#               print('        Array:            '.$array->{array}."\n");
#               print('          Power:          '.$array->{power}."\n");
#               print('          Current:        '.$array->{current}."\n");
#               print('          Voltage:        '.$array->{voltage}."\n");
            }
        }
    }

    Log(1, "_givEnergy_ProcessSiteProductInverter: getLatestMeterData ");


    my $meterData = $givEnergyClient->getLatestMeterData($productInverter->{serial});
    if (!$meterData) {
        Log(1, "_givEnergy_ProcessSiteProductInverter: Failed to get latest meter data for inverter - ".$productInverter->{serial});
    } else {
        my $data = $meterData->{data};

        Log(1, "_givEnergy_ProcessSiteProductInverter: getLatestMeterData (got)");
#        print('      Time:          '.$data->{time}."\n");

#        my $today = $data->{today};
#        print("      Today:  \n");
#        print('        Consumption: '.$today->{consumption}."\n");
#        print('        Solar:       '.$today->{solar}."\n");
#        print("        Grid:      \n");
#        print('          Import:    '.$today->{grid}->{import}."\n");
#        print('          Export:    '.$today->{grid}->{export}."\n");
#        print("        Battery:    \n");
#        print('          Charge:    '.$today->{battery}->{charge}."\n");
#        print('          Discharge: '.$today->{battery}->{discharge}."\n");

#        my $total = $data->{total};
#        print("      Total:  \n");
#        print('        Consumption: '.$total->{consumption}."\n");
#        print('        Solar:       '.$total->{solar}."\n");
#        print("        Grid:      \n");
#        print('          Import:    '.$total->{grid}->{import}."\n");
#        print('          Export:    '.$total->{grid}->{export}."\n");
#        print("        Battery:    \n");
#        print('          Charge:    '.$total->{battery}->{charge}."\n");
#        print('          Discharge: '.$total->{battery}->{discharge}."\n");

    }

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
                _givEnergy_ProcessSiteProductInverter($hash, $givEnergyClient, $productInverter);
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


