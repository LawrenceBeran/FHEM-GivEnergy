package GivEnergyInterface;
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use JSON;
use Data::Dumper;
use Carp qw(croak);
use Readonly;

# See https://portal.givenergy.cloud/docs/api/v1#introduction for details on the GivEnergy API

# Common logging levels..
Readonly my $LL_FATAL = 0;
Readonly my $LL_ERROR = 1;
Readonly my $LL_WARNING = 2;
Readonly my $LL_INFO = 3;
Readonly my $LL_DEBUG = 4;
Readonly my $LL_TRACE = 5;


sub new {       # constructor, this method makes an object that belongs to class Number
    my $class = shift;          # $_[0] contains the class name

    croak 'Illegal parameter list has odd number of values' 
        if @_ % 2;

    my %params = @_;

    my $self = {};              # the internal structure we'll use to represent
                                # the data in our class is a hash reference
    bless( $self, $class );     # make $self an object of class $class

    # This could be abstracted out into a method call if you 
    # expect to need to override this check.
    for my $required (qw{ token  }) {
        croak "Required parameter '$required' not passed to '$class' constructor"
            unless exists $params{$required};
    }

    # initialise class members, these can be overriden by class initialiser.
    $self->{token}   = undef;

    # initialize all attributes by passing arguments to accessor methods.
    for my $attrib ( keys %params ) {

        croak "Invalid parameter '$attrib' passed to '$class' constructor"
            unless $self->can( $attrib );

        $self->$attrib( $params{$attrib} );
    }

    # Provide a value to the following to log all successfull API calls and responses at the log level defined in - $self->{infoLogLevel}
    # Set it to undef to not log all responses, errors are still logged
    $self->{logAPIResponsesLevel} = $LL_TRACE;
    $self->{infoLogLevel} = $LL_DEBUG;

    $self->{URL} = 'https://api.givenergy.cloud/';
    $self->{version} = 'v1';

    $self->{ua} = LWP::UserAgent->new;

    return $self;        # a constructor always returns an blessed() object
}

sub DESTROY($)
{
    my $self = shift;

    $self->_log($LL_TRACE, 'DESTROY - Enter');
}

# Attribute accessor method.
sub token($$) {
    my ($self, $value) = @_;
    if (@_ == 2) {
        $self->{token} = $value;
    }
    return $self->{token};
}

#############################################

sub _log($$$) {
    my ( $self, $loglevel, $text ) = @_;

    my $xline = (caller(0))[2];
    my $xsubroutine = (caller(1))[3];
    my $sub = (split( ':', $xsubroutine ))[2];

    main::Log3('GivEnergyInterface', $loglevel, "${sub}.${xline} ${text}");
}

sub _getURL($$) {
    my ($self, $path) = @_;
    return $self->{URL}.$self->{version}.'/'.$path;
}

sub _getHeaders($) {
    my ($self) = @_;
    my $header = [  'Content-Type' => 'application/json'
                ,   'Accept' => 'application/json'
                ,   'Authorization' => 'Bearer '.$self->{token}
                ];
    return $header;
}

sub _get($$$$) {
    my ($self, $path, $post_data, $page) = @_;

    if ($page) {
        $post_data->{page} = $page;
        $post_data->{pageSize} = 15;
    }

    my $request_getdata = HTTP::Request->new('GET', $self->_getURL($path), $self->_getHeaders(), $post_data ? to_json($post_data) : undef);
    my $resp_getdata = $self->{ua}->request($request_getdata);

    if (!$resp_getdata->is_success) {
        $self->_log(1, $path.' - '.$resp_getdata->decoded_content);
        return undef;
    }

    my $resp_getdata_json = decode_json($resp_getdata->decoded_content);
    $self->_log($self->{logAPIResponsesLevel}, $path.' - '.Dumper($resp_getdata_json));

    return $resp_getdata_json;
}

sub getSites($) {
    my ($self) = @_;

    return $self->_get('site', undef, 1);
}

sub getSiteById($$) {
    my ($self, $site_id) = @_;

    return $self->_get("site/'${site_id}", undef, 1);
}

sub getCommunicationDevices($) {
    my ($self) = @_;

    return $self->_get('communication-device', undef, 1);
}

sub getLatestSystemData($$) {
    my ($self, $inverter_serialnumber) = @_;

    return $self->_get("inverter/${inverter_serialnumber}/system-data/latest", undef, undef);
}

sub getLatestMeterData($$) {
    my ($self, $inverter_serialnumber) = @_;

    return $self->_get("inverter/${inverter_serialnumber}/meter-data/latest", undef, undef);
}

sub getAccountInformation($) {
    my ($self) = @_;

    return $self->_get('account', undef, undef);
}

sub getAccountDongles($$) {
    my ($self, $account_id) = @_;

    return $self->_get("account/${account_id}/devices", undef, 1);
}


1;