use strict;
use warnings;

use FindBin 1.51 qw( $RealBin );
use lib ($RealBin);
#use lib '.';
use GivEnergyInterface;

use Data::Dumper;

my $token_filename = 'GivEnergy.token';
my $token = undef;

### Load the previous token from file
my $tokenString = do {
    open(my $fhIn, "<", $token_filename);
    local $/;
    <$fhIn>
};

if (defined($tokenString))
{
    $token = $tokenString;
} else {
    # TODO - cant run without a token!
}

#print($token."\n");


### Create an instance of the GivEnergy API class, passing in our token
my $givEnergyClient = GivEnergyInterface->new(token => $token);


my $respAccountInfo = $givEnergyClient->getAccountInformation();
if ($respAccountInfo) {

    my $account  = $respAccountInfo->{data};

    my $respAccountDongles = $givEnergyClient->getAccountDongles($account->{id});
}



# Get all sites
my $respSites = $givEnergyClient->getSites();
foreach my $site (@{$respSites->{data}}) {

    # Not necessary as all site details are in the $respSites returned object, this is to test the API call.
    my $respSite = $givEnergyClient->getSiteById($site->{id});
    if (!$respSite) {
        # TODO:
    } else {

        my $siteData = $respSite->{data};

        print("\nSite:          ".$siteData->{id}."\n");
        print('  Name:        '.$siteData->{name}."\n");
        print('  Country:     '.$siteData->{country}."\n");
        print('  Timezone:    '.$siteData->{timezone}."\n");
        print('  Latitude:    '.$siteData->{latitude}."\n");
        print('  Longitude:   '.$siteData->{longitude}."\n");
        print('  Account:     '.$siteData->{account}."\n");
        print('  DateCreated: '.$siteData->{date_created}."\n");
      
        foreach my $product (@{$siteData->{products}}) {

            if (lc($product->{name}) eq 'inverters') {

                foreach my $productInverter (@{$product->{data}}) {
                
                    print("\n  Inverter:          ".$productInverter->{serial}."\n");
                    print('    Status:          '.$productInverter->{status}."\n");
                    print('    Model:           '.$productInverter->{info}->{model}."\n");
                    print('    Battery type:    '.$productInverter->{info}->{battery_type}."\n");
                    print('    Warranty:        '.$productInverter->{warranty}->{type}.", expiry - ".$productInverter->{warranty}->{expiry_date}."\n");
                    print('    Commission date: '.$productInverter->{commission_date}."\n");
                    print('    Last online:     '.$productInverter->{last_online}."\n");
                    print('    Last updated:    '.$productInverter->{last_updated}."\n");
                    print("    Firmware versions:\n");
                    foreach my $firmware (keys %{$productInverter->{firmware_version}}) {
                        print('      '.$firmware.':            '.$productInverter->{firmware_version}->{$firmware}."\n");
                    }
                    # TODO: connections!

                    print("\n    System data:\n");

                    my $systemData = $givEnergyClient->getLatestSystemData($productInverter->{serial});

                    if (!$systemData) {
                        # TODO:
                    } else {
                        my $data = $systemData->{data};

                        print('      Time:               '.$data->{time}."\n");
                        print('      Consumption:        '.$data->{consumption}."\n");


                        my $dataInverter = $data->{inverter};
                        print("      Inverter:\n");
                        print('        Power:            '.$dataInverter->{power}."\n");
                        print('        Temperature:      '.$dataInverter->{temperature}."\n");
                        print('        EPS power:        '.$dataInverter->{eps_power}."\n");
                        print('        Output frequency: '.$dataInverter->{output_frequency}."\n");
                        print('        Output voltage:   '.$dataInverter->{output_voltage}."\n");

                        my $dataGrid = $data->{grid};
                        print("      Grid:\n");
                        print('        Power:            '.$dataGrid->{power}."\n");
                        print('        Current:          '.$dataGrid->{current}."\n");
                        print('        Frequency:        '.$dataGrid->{frequency}."\n");
                        print('        Voltage:          '.$dataGrid->{voltage}."\n");

                        my $dataBattery = $data->{battery};
                        print("      Battery:\n");
                        print('        Power:            '.$dataBattery->{power}."\n");
                        print('        Temperature:      '.$dataBattery->{temperature}."\n");
                        print('        Percentage:       '.$dataBattery->{percent}."\n");

                        my $dataSolar = $data->{solar};
                        print("      Solar:\n");
                        print("        Power:            ".$dataSolar->{power}."\n");

                        foreach my $array (@{$dataSolar->{arrays}}) {
                            print('        Array:            '.$array->{array}."\n");
                            print('          Power:          '.$array->{power}."\n");
                            print('          Current:        '.$array->{current}."\n");
                            print('          Voltage:        '.$array->{voltage}."\n");
                        }
                    }

                    print("\n    Meter data:\n");

                    my $meterData = $givEnergyClient->getLatestMeterData($productInverter->{serial});

                    if (!$meterData) {
                        # TODO:
                    } else {
                        my $data = $meterData->{data};

                        print('      Time:          '.$data->{time}."\n");

                        my $today = $data->{today};
                        print("      Today:  \n");
                        print('        Consumption: '.$today->{consumption}."\n");
                        print('        Solar:       '.$today->{solar}."\n");
                        print("        Grid:      \n");
                        print('          Import:    '.$today->{grid}->{import}."\n");
                        print('          Export:    '.$today->{grid}->{export}."\n");
                        print("        Battery:    \n");
                        print('          Charge:    '.$today->{battery}->{charge}."\n");
                        print('          Discharge: '.$today->{battery}->{discharge}."\n");

                        my $total = $data->{total};
                        print("      Total:  \n");
                        print('        Consumption: '.$total->{consumption}."\n");
                        print('        Solar:       '.$total->{solar}."\n");
                        print("        Grid:      \n");
                        print('          Import:    '.$total->{grid}->{import}."\n");
                        print('          Export:    '.$total->{grid}->{export}."\n");
                        print("        Battery:    \n");
                        print('          Charge:    '.$total->{battery}->{charge}."\n");
                        print('          Discharge: '.$total->{battery}->{discharge}."\n");
                    }
                }
            }
        }
    }
}


print("\nCommunication devices:");

my $respData = $givEnergyClient->getCommunicationDevices();

foreach my $item (@{$respData->{data}}) {

    print("\n  Serial number:     ".$item->{serial_number}."\n");
    print("  Type:              ".$item->{type}."\n");
    print("  Commission date:   ".$item->{commission_date}."\n");

    my $inverter = $item->{inverter};

    print("  Inverter:    \n");
    print("    Serial number     ".$inverter->{serial}."\n");
    print("    Status            ".$inverter->{status}."\n");
    print("    Model             ".$inverter->{info}->{model}."\n");
    print("    Battery type      ".$inverter->{info}->{battery_type}."\n");
    print("    Warranty:         ".$inverter->{warranty}->{type}.", expiry - ".$inverter->{warranty}->{expiry_date}."\n");
    print("    Commissioned      ".$inverter->{commission_date}."\n");
    print("    Last online       ".$inverter->{last_online}."\n");
    print("    Last updated      ".$inverter->{last_updated}."\n");
    foreach my $firmware (keys %{$inverter->{firmware_version}}) {
        print('      '.$firmware.':            '.$inverter->{firmware_version}->{$firmware}."\n");
    }
    # TODO: connections!
}



### Save the token to file
open(my $fhOut, ">", $token_filename);
print($fhOut $token);
close($fhOut);  

sub Log3
{
    # This subroutine mimics the interface of the FHEM defined Log so that the test does not crash.
    my $var = '';

}