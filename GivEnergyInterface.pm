package GivEnergyInterface;
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use JSON;
use Data::Dumper;
use Carp qw(croak);

sub new        # constructor, this method makes an object that belongs to class Number
{
    my $class = shift;          # $_[0] contains the class name

    croak "Illegal parameter list has odd number of values" 
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
    $self->{logAPIResponsesLevel} = 5;
    $self->{infoLogLevel} = 4;

    $self->{URL} = 'https://api.givenergy.cloud/';
    $self->{version} = 'v1';

    $self->{ua} = LWP::UserAgent->new;

    return $self;        # a constructor always returns an blessed() object
}

sub DESTROY($)
{
    my $self = shift;

    $self->_log(5, "DESTROY - Enter");
}

# Attribute accessor method.
sub token($$) 
{
    my ($self, $value) = @_;
    if (@_ == 2) 
    {
        $self->{token} = $value;
    }
    return $self->{token};
}

sub _getURL($$)
{
    my ($self, $path) = @_;
    return $self->{URL}.$self->{version}.'/'.$path;
}

sub _getHeaders($)
{
    my ($self) = @_;
    my $header = [  'Content-Type' => 'application/json'
                ,   'Accept' => 'application/json'
                ,   'Authorization' => 'Bearer '.$self->{token}
                ];
    return $header;
}

sub getCommunicationDevices($)
{
    my ($self) = @_;

    my $postData = {
            page => '1'
        ,   pageSize => '15'
    };

    my $requestGetData = HTTP::Request->new('GET', $self->_getURL('communication-device'), $self->_getHeaders(), to_json($postData));
    my $respGetData = $self->{ua}->request($requestGetData);

    if (!$respGetData->is_success) {
        $self->_log(1, $respGetData->decoded_content);
        return undef;
    }

    my $respGetDataJSON = decode_json($respGetData->decoded_content);
    $self->_log($self->{logAPIResponsesLevel}, Dumper($respGetDataJSON));

    return $respGetDataJSON
}