use strict;
use warnings;

use FindBin 1.51 qw( $RealBin );
use lib ($RealBin, ".");


use GivEnergyInterface;

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

### Connect to the GivEnergy API
my $givEnergyClient = GivEnergyInterface->new(token => $token);




### Save the token to file
open(my $fhOut, ">", $token_filename);
print($fhOut $token);
close($fhOut);  

sub Log3
{
    # This subroutine mimics the interface of the FHEM defined Log so that the test does not crash.
    my $var = '';
}