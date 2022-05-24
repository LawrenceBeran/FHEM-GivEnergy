package main;
use strict;
use warnings;
use Readonly;

# Common logging levels..
Readonly my $LL_FATAL = 0;
Readonly my $LL_ERROR = 1;
Readonly my $LL_WARNING = 2;
Readonly my $LL_INFO = 3;
Readonly my $LL_DEBUG = 4;
Readonly my $LL_TRACE = 5;


sub GivEnergy_ProductInverter_Initialize($) {
	my ($hash) = @_;

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Initialize: enter');

	# Provider

	# Consumer
	$hash->{DefFn}    = 'GivEnergy_ProductInverter_Define';
#	$hash->{SetFn}    = 'GivEnergy_ProductInverter_Set';	
	$hash->{ParseFn}  = 'GivEnergy_ProductInverter_Parse';
	$hash->{Match}    = '^GivEnergy_ProductInverter';                 # The start of the Dispatch/Parse message must contain this string to match this device.
#	$hash->{AttrFn}   = 'GivEnergy_ProductInverter_Attr';
	$hash->{AttrList} = 'IODev "'
#					  . 'autoAlias:1,0 '
					  . $readingFnAttributes;

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Initialize: exit');

	return undef;
}

sub GivEnergy_ProductInverter_CheckIODev($) {
	my $hash = shift;
	return !defined($hash->{IODev}) || ($hash->{IODev}{TYPE} ne 'GivEnergy_ProductInverter');
}

sub GivEnergy_ProductInverter_Define($$) {
	my ($hash, $def) = @_;

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Define: enter');

	my ($name, $type, $serialId, $siteId) = split('[ \t][ \t]*', $def);

	if (exists($modules{GivEnergy_ProductInverter}{defptr}{$serialId})) 
	{
		my $msg = "GivEnergy_ProductInverter_Define: Product Inverter with serial '${serialId}' is already defined";
		Log($LL_ERROR, $msg);
		return $msg;
	}

	Log(1, "GivEnergy_ProductInverter_Define serial '${serialId}'");
	$hash->{serial}    = $serialId;
	$hash->{STATE}     = 'Disconnected';

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

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Define: exit');

	return undef;
}

sub GivEnergy_ProductInverter_Undefine($$) {
	my ($hash,$arg) = @_;

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Undefine: enter');

	delete($modules{GivEnergy_ProductInverter}{defptr}{$hash->{id}});

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Undefine: exit');

	return undef;
}

sub report_meter_data_reading($$$) {
	my ($shash, $tag, $data) = @_;

	readingsBulkUpdate($shash, $tag.'Consumption', $data->{consumption});
	readingsBulkUpdate($shash, $tag.'Solar', $data->{solar});
	readingsBulkUpdate($shash, $tag.'GridImport', $data->{grid}->{import});
	readingsBulkUpdate($shash, $tag.'GridExport', $data->{grid}->{export});
	readingsBulkUpdate($shash, $tag.'BatteryCharge', $data->{battery}->{charge});
	readingsBulkUpdate($shash, $tag.'BatteryDischarge', $data->{battery}->{discharge});
	return undef;
}

sub GivEnergy_ProductInverter_Parse($$$) {
	my ($hash, $msg, $device) = @_;
	my ($name, $serial_id, $site_id, $product_inverter_string) = split(',', $msg, 4);

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Parse: enter');

	# Convert the productInverter details back to JSON.
	my $product_inverter = decode_json($product_inverter_string);

	# TODO: Validate that the message is actually for a product inverter... (is this required here? The define should have done that)

	if (!exists($modules{GivEnergy_ProductInverter}{defptr}{$serialId})) 
	{
		Log($LL_ERROR, "GivEnergy_ProductInverter_Parse: Product Inverter ${serial_id} doesnt exist: ${name}");
		if (lc($product_inverter->{serial}) eq lc($serial_id)) {
			return "UNDEFINED ${name}_".${serial_id} =~ tr/-/_/r." ${name} ${serial_id} ${site_id}";
		}
		Log($LL_ERROR, 'GivEnergy_ProductInverter_Parse: Invalid parameters provided to be able to autocreate the device!');
		return 'Invalid parameters provided to be able to autocreate the device!';
	}

	my $my_state = 'Disconnected';

	# Get the hash of the Hive device object
	my $shash = $modules{GivEnergy_ProductInverter}{defptr}{$serial_id};

	if (lc($product_inverter->{serial}) eq lc($serial_id))
	{
		$shash->{model}             = $product_inverter->{info}->{model};
		$shash->{batteryType}       = $product_inverter->{info}->{battery_type};
		$shash->{warrentyType}      = $product_inverter->{warranty}->{type};
		$shash->{warrentyExpiry}    = $product_inverter->{warranty}->{expiry_date};
		$shash->{commissionDate}    = $product_inverter->{commission_date};
		$shash->{lastOnline}        = $product_inverter->{last_online};
		$shash->{lastUpdated}       = $product_inverter->{last_updated};

        foreach my $firmware (keys %{$product_inverter->{firmware_version}}) {
			$shash->{'firmware'.$firmware.'Version'} = $product_inverter->{firmware_version}->{$firmware};
        }
        # TODO: connections!  

		readingsBeginUpdate($shash);

		my $system_data = $product_inverter->{systemData};
		if ($system_data) {
			if (readingsBulkUpdateIfChanged($shash, 'systemDataTime', $system_data->{time})) {
				readingsBulkUpdate($shash, 'consumption', $system_data->{consumption});
				if ($system_data->{inverter}) {
					readingsBulkUpdate($shash, 'inverterPower', $system_data->{inverter}->{power});
					readingsBulkUpdate($shash, 'inverterEPSPower', $system_data->{inverter}->{eps_power});
					readingsBulkUpdate($shash, 'inverterOutputFrequency', $system_data->{inverter}->{output_frequency});
					readingsBulkUpdate($shash, 'inverterTemperature', $system_data->{inverter}->{temperature});
					readingsBulkUpdate($shash, 'inverterOutputVoltage', $system_data->{inverter}->{output_voltage});
				}
				if ($system_data->{grid}) {
					readingsBulkUpdate($shash, 'gridPower', $system_data->{grid}->{power});
					readingsBulkUpdate($shash, 'gridCurrent', $system_data->{grid}->{current});
					readingsBulkUpdate($shash, 'gridFrequency', $system_data->{grid}->{frequency});
					readingsBulkUpdate($shash, 'gridVoltage', $system_data->{grid}->{voltage});
				}
				if ($system_data->{battery}) {
					readingsBulkUpdate($shash, 'batteryPower', $system_data->{battery}->{power});
					readingsBulkUpdate($shash, 'batteryPercentage', $system_data->{battery}->{percent});
					readingsBulkUpdate($shash, 'batteryTemperature', $system_data->{battery}->{temperature});
				}
				if ($system_data->{solar}) {
					readingsBulkUpdate($shash, 'solarPower', $system_data->{solar}->{power});
					foreach my $array (@{$system_data->{solar}->{arrays}}) {
						my $array_name = 'solarArray'.$array->{array};
						readingsBulkUpdate($shash, $array_name.'Power', $array->{power});
						readingsBulkUpdate($shash, $array_name.'Current', $array->{current});
						readingsBulkUpdate($shash, $array_name.'Voltage', $array->{voltage});
					}
				}
			}
		}

		my $meter_data = $product_inverter->{meterData};
		if ($meter_data) {
			if (readingsBulkUpdateIfChanged($shash, 'meterDataTime', $meter_data->{time})) {
				report_meter_data_reading($shash, 'today', $meter_data->{today});
				report_meter_data_reading($shash, 'total', $meter_data->{total});
			}
		}
		$my_state = $product_inverter->{status};

		readingsBulkUpdateIfChanged($shash, 'state', $my_state);

		readingsEndUpdate($shash, 1);
	}

	Log($LL_TRACE, 'GivEnergy_ProductInverter_Parse: exit');

	return $shash->{NAME};
}




1;

