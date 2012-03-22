#! /usr/bin/env perl
###################################################
#
#  Copyright (C) <year> <author> <<email>>
#
#  This file is part of Shutter.
#
#  Shutter is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  Shutter is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Shutter; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
###################################################
 
package PixAm;                                                       #edit
 
use lib $ENV{'SHUTTER_ROOT'}.'/share/shutter/resources/modules';
 
use utf8;
use strict;
use POSIX qw/setlocale/;
use Locale::gettext;
use Glib qw/TRUE FALSE/;
use Data::Dumper;
 
use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);
 
my $d = Locale::gettext->domain("shutter-plugins");
$d->dir( $ENV{'SHUTTER_INTL'} );
 
my %upload_plugin_info = (
    'module'                        => "PixAm",                       #edit (must be the same as 'package')
    'url'                           => "http://provider.com/",           #edit (the website's url)
    'registration'                  => "http://provider.com/register",   #edit (a link to the registration page)
    'name'                          => "PROVIDER",                       #edit (the provider's name)
    'description'                   => "Upload screenshots to PROVIDER",#edit (a description of the service)
    'supports_anonymous_upload'     => FALSE,                         #TRUE if you can upload *without* username/password
    'supports_authorized_upload'    => TRUE,                         #TRUE if username/password are supported (might be in addition to anonymous_upload)
    'supports_oauth_upload'         => FALSE,                            #TRUE if OAuth is used (see Dropbox.pm as an example)
);
 
binmode( STDOUT, ":utf8" );
if ( exists $upload_plugin_info{$ARGV[ 0 ]} ) {
    print $upload_plugin_info{$ARGV[ 0 ]};
    exit;
}
 
#don't touch this
sub new {
    my $class = shift;
 
    #call constructor of super class (host, debug_cparam, shutter_root, gettext_object, main_gtk_window, ua)
    my $self = $class->SUPER::new( shift, shift, shift, shift, shift, shift );
 
    bless $self, $class;
    return $self;
}
 
#load some custom modules here (or do other custom stuff)
sub init {
    my $self = shift;
 
    use JSON;                   #example1
    use LWP::UserAgent;         #example2
    use HTTP::Request::Common;  #example3
 
    return TRUE;
}
 
#handle
sub upload {
    my ( $self, $upload_filename, $username, $password ) = @_;
 
    #store as object vars
    $self->{_filename} = $upload_filename;
    $self->{_username} = $username;
    $self->{_password} = $password;
 
    utf8::encode $upload_filename;
    utf8::encode $password;
    utf8::encode $username;

    #$self->{user_id} = false;
    #$self->{hash} = false;
 
    #examples related to the sub 'init'
    my $json_coder = JSON::XS->new;
 
    my $client = LWP::UserAgent->new(
        'timeout'    => 20,
        'keep_alive' => 10,
        'env_proxy'  => 1,
    );
 
    #username/password are provided
    if ( $username ne "" && $password ne "" ) {
 
        eval{
            my %params = (
                    'email' => $self->{_username},
                    'password'   => $self->{_password},
            );

            my @params = (
                    "http://pix.am/api/auth/",
                    'Content_Type' => 'multipart/form-data',
                    'Content' => [%params]
            );

            my $json = JSON->new();

            my $req = HTTP::Request::Common::POST(@params);
            my $rsp = $client->request($req);

            my $login_info = $json->decode( $rsp->content );

            if($login_info->{error}) {
                $self->{_links}{'status'} = 999;
                if($self->{_debug_cparam}) {
                    print $login_info->{error} . "\n";
                }
            } else {
                $self->{user_id} = $login_info->{user_id};
                $self->{hash} = $login_info->{user_hash};
                if($self->{_debug_cparam}) {
                    print "Got user_id: " . $self->{user_id} . " hash:" . $self->{hash} . "\n";
                }
            }

        };
        if($@){
            $self->{_links}{'status'} = $@;
            return %{ $self->{_links} };
        }
        if($self->{_links}{'status'} == 999){
            return %{ $self->{_links} };
        }
 
    }
 
    #upload the file
    eval{
 
        #########################
        #put the upload code here
        #########################
        my $json = JSON->new();

        my %params = (
                'image' => [$self->{_filename}]#,
                #'user_id'   => $self->{user_id},
                #'user_hash' => $self->{hash}
        );
        if($self->{user_id} && $self->{hash}) {
            %params->{user_id} = $self->{user_id};
            %params->{user_hash} = $self->{hash}
        }

        my @params = (
                'http://pix.am/post/',
                'Content_Type' => 'form-data',
                'Content' => [%params]                               
        );

        my $req = HTTP::Request::Common::POST(@params);
        push @{ $client->requests_redirectable }, 'POST';
        my $rsp = $client->request($req);

        #save all retrieved links to a hash, as an example:
        $self->{_links}->{'direct_link'} = $rsp->content;
        # $self->{_links}->{'short_link'} = 'mylink2';
        # $self->{_links}->{'bbcode'} = 'mylink3';
 
        #set success code (200)
        $self->{_links}{'status'} = 200;
 
    };
    if($@){
        $self->{_links}{'status'} = $@;
    }
 
    #and return links
    return %{ $self->{_links} };
}
 
#you are free to implement some custom subs here, but please make sure they don't interfere with Shutter's subs
#hence, please follow this naming convention: _<provider>_sub (e.g. _imageshack_convert_x_to_y)
 
1;