package main;
use strict;
use warnings;

sub GivEnergy_ProductInverter_Initialize($)
{
	my ($hash) = @_;

	Log(5, "GivEnergy_ProductInverter_Initialize: enter");

	# Provider

	# Consumer
	$hash->{DefFn}		= "GivEnergy_ProductInverter_Define";
#	$hash->{SetFn}    	= "GivEnergy_ProductInverter_Set";	
	$hash->{ParseFn}	= "GivEnergy_ProductInverter_Parse";
	$hash->{Match}		= "^GivEnergy_ProductInverter";			# The start of the Dispatch/Parse message must contain this string to match this device.
#	$hash->{AttrFn}		= "GivEnergy_ProductInverter_Attr";
	$hash->{AttrList}	= "IODev " 
#						. "autoAlias:1,0 "
						. $readingFnAttributes;

	Log(5, "GivEnergy_ProductInverter_Initialize: exit");

	return undef;
}

sub GivEnergy_ProductInverter_CheckIODev($)
{
	my $hash = shift;
	return !defined($hash->{IODev}) || ($hash->{IODev}{TYPE} ne "GivEnergy_ProductInverter");
}

sub GivEnergy_ProductInverter_Define($$)
{
	my ($hash, $def) = @_;

	Log(1, "GivEnergy_ProductInverter_Define: enter");

	my ($name, $type, $serialId, $siteId) = split("[ \t][ \t]*", $def);

	if (exists($modules{GivEnergy_ProductInverter}{defptr}{$serialId})) 
	{
		my $msg = "GivEnergy_ProductInverter_Define: Product Inverter with serial '${serialId}' is already defined";
		Log(1, "$msg");
		return $msg;
	}

	Log(1, "GivEnergy_ProductInverter_Define serial '${serialId}'");
	$hash->{serial} 	= $serialId;
	$hash->{STATE}		= 'Disconnected';

	$modules{GivEnergy_ProductInverter}{defptr}{$serialId} = $hash;

	# Tell this Hive device to point to its parent HiveHome
	AssignIoPort($hash);

	# Need to call HiveHome_UpdateNodes....
	if (defined($hash->{IODev}{InitNode}))
	{
		($hash->{IODev}{InitNode})->($hash->{IODev}, 1);

		$attr{$name}{room}  = 'GivEnergy';
	} else {
		# TODO: Cant properly define the object!
	}

	Log(1, "GivEnergy_ProductInverter_Define: exit");

	return undef;
}

sub GivEnergy_ProductInverter_Undefine($$)
{
	my ($hash,$arg) = @_;

	Log(5, "GivEnergy_ProductInverter_Undefine: enter");

	delete($modules{GivEnergy_ProductInverter}{defptr}{$hash->{id}});
	
	Log(5, "GivEnergy_ProductInverter_Undefine: exit");

	return undef;
}

sub reportMeterDataReading($$$) {
	my ($shash, $tag, $data) = @_;

	readingsBulkUpdate($shash, $tag."Consumption", $data->{consumption});
	readingsBulkUpdate($shash, $tag."Solar", $data->{solar});
	readingsBulkUpdate($shash, $tag."GridImport", $data->{grid}->{import});
	readingsBulkUpdate($shash, $tag."GridExport", $data->{grid}->{export});
	readingsBulkUpdate($shash, $tag."BatteryCharge", $data->{battery}->{charge});
	readingsBulkUpdate($shash, $tag."BatteryDischarge", $data->{battery}->{discharge});
}

sub GivEnergy_ProductInverter_Parse($$$)
{
	my ($hash, $msg, $device) = @_;
	my ($name, $serialId, $siteId, $productInverterString) = split(",", $msg, 4);

	Log(5, "GivEnergy_ProductInverter_Parse: enter");

	# Convert the productInverter details back to JSON.
	my $productInverter = decode_json($productInverterString);

	# TODO: Validate that the message is actually for a product inverter... (is this required here? The define should have done that)
	
	if (!exists($modules{GivEnergy_ProductInverter}{defptr}{$serialId})) 
	{
		Log(1, "GivEnergy_ProductInverter_Parse: Product Inverter ${serialId} doesnt exist: ${name}");
		if (lc($productInverter->{serial}) eq lc($serialId)) {
			return "UNDEFINED ${name}_".${serialId} =~ tr/-/_/r." ${name} ${serialId} ${siteId}";
		}
		Log(1, "GivEnergy_ProductInverter_Parse: Invalid parameters provided to be able to autocreate the device!");
		return "Invalid parameters provided to be able to autocreate the device!";
	}

	my $myState = "Disconnected";

	# Get the hash of the Hive device object
	my $shash = $modules{GivEnergy_ProductInverter}{defptr}{$serialId};

	if (lc($productInverter->{serial}) eq lc($serialId))
	{
		$shash->{model}             = $productInverter->{info}->{model};
		$shash->{batteryType}       = $productInverter->{info}->{battery_type};
		$shash->{warrentyType}      = $productInverter->{warranty}->{type};
		$shash->{warrentyExpiry}    = $productInverter->{warranty}->{expiry_date};
		$shash->{commissionDate}    = $productInverter->{commission_date};
		$shash->{lastOnline}        = $productInverter->{last_online};
		$shash->{lastUpdated}       = $productInverter->{last_updated};

        foreach my $firmware (keys %{$productInverter->{firmware_version}}) {
			$shash->{'firmware'.$firmware."Version"} = $productInverter->{firmware_version}->{$firmware};
        }
        # TODO: connections!  

		readingsBeginUpdate($shash);

		my $systemData = $productInverter->{systemData};
		if ($systemData) {
			if (readingsBulkUpdateIfChanged($shash, "systemDataTime", $systemData->{time})) {
				readingsBulkUpdate($shash, "consumption", $systemData->{consumption});
				if ($systemData->{inverter}) {
					readingsBulkUpdate($shash, "inverterPower", $systemData->{inverter}->{power});
					readingsBulkUpdate($shash, "inverterEPSPower", $systemData->{inverter}->{eps_power});
					readingsBulkUpdate($shash, "inverterOutputFrequency", $systemData->{inverter}->{output_frequency});
					readingsBulkUpdate($shash, "inverterTemperature", $systemData->{inverter}->{temperature});
					readingsBulkUpdate($shash, "inverterOutputVoltage", $systemData->{inverter}->{output_voltage});
				}
				if ($systemData->{grid}) {
					readingsBulkUpdate($shash, "gridPower", $systemData->{grid}->{power});
					readingsBulkUpdate($shash, "gridCurrent", $systemData->{grid}->{current});
					readingsBulkUpdate($shash, "gridFrequency", $systemData->{grid}->{frequency});
					readingsBulkUpdate($shash, "gridVoltage", $systemData->{grid}->{voltage});
				}
				if ($systemData->{battery}) {
					readingsBulkUpdate($shash, "batteryPower", $systemData->{battery}->{power});
					readingsBulkUpdate($shash, "batteryPercentage", $systemData->{battery}->{percent});
					readingsBulkUpdate($shash, "batteryTemperature", $systemData->{battery}->{temperature});
				}
				if ($systemData->{solar}) {
					readingsBulkUpdate($shash, "solarPower", $systemData->{solar}->{power});
					foreach my $array (@{$systemData->{solar}->{arrays}}) {
						my $arrayName = "solarArray".$array->{array};
						readingsBulkUpdate($shash, $arrayName."Power", $array->{power});
						readingsBulkUpdate($shash, $arrayName."Current", $array->{current});
						readingsBulkUpdate($shash, $arrayName."Voltage", $array->{voltage});
					}
				}
			}
		}

		my $meterData = $productInverter->{meterData};
		if ($meterData) {
			if (readingsBulkUpdateIfChanged($shash, "meterDataTime", $meterData->{time})) {
				reportMeterDataReading($shash, "today", $meterData->{today});
				reportMeterDataReading($shash, "total", $meterData->{total});
			}
		}
		$myState = $productInverter->{status};

		readingsBulkUpdateIfChanged($shash, "state", $myState);

		readingsEndUpdate($shash, 1);
	}

	Log(5, "GivEnergy_ProductInverter_Parse: exit");

	return $shash->{NAME};
}




1;

