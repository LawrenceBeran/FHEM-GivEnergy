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

print($token."\n");


### Connect to the GivEnergy API
my $givEnergyClient = GivEnergyInterface->new(token => $token);


# Get all sites
my $respSites = $givEnergyClient->getSites();
foreach my $site (@{$respSites->{data}}) {

    my $respSite = $givEnergyClient->getSiteById($site->{id});
    #print(Dumper($respSite));

    foreach my $product (@{$respSite->{data}->{products}}) {

        if (lc($product->{name}) eq 'inverters') {

            foreach my $productInverter (@{$product->{data}}) {
            
#                print(Dumper($productInverter));

                my $systemData = $givEnergyClient->getSystemDataLatest($productInverter->{serial});

                print(Dumper($systemData));

           }
        }
    }
}



my $respData = $givEnergyClient->getCommunicationDevices();

foreach my $item (@{$respData->{data}}) {
#    print(Dumper($item));

    print("Serial number: -   ".$item->{serial_number}."\n");
    print("Type: -            ".$item->{type}."\n");
    print("Commission date: - ".$item->{commission_date}."\n");

    my $inverter = $item->{inverter};
#    print(Dumper($inverter));

    print("Inverter:    \n");
    print("   Serial number -   ".$inverter->{serial}."\n");
    print("   Status -          ".$inverter->{status}."\n");
    print("   Last online -     ".$inverter->{last_online}."\n");
    print("   Model -           ".$inverter->{info}->{model}."\n");

    my $systemData = $givEnergyClient->getSystemDataLatest($inverter->{serial});

    print(Dumper($systemData));
}

#print(Dumper($respData->{data}[0]->{inverter}));
#print(Dumper($respData->{data}[0]->{inverter}->{serial}));
#print(Dumper($respData));



### Save the token to file
open(my $fhOut, ">", $token_filename);
print($fhOut $token);
close($fhOut);  

sub Log3
{
    # This subroutine mimics the interface of the FHEM defined Log so that the test does not crash.
    my $var = '';

}