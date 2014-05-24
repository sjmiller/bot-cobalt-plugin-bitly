package Bot::Cobalt::Plugin::Bitly;
# ABSTRACT: Bot::Cobalt plugin for auto-shortening URL via Bit.ly

use strict;
use warnings;

use Bot::Cobalt;
use Bot::Cobalt::Common;

use URI::Find::Simple;
use WebService::Bitly;

sub new        { bless {}, shift }
sub bitly      { shift->{bitly} }
sub min_length { shift->{min_length} }

sub Cobalt_register {
   my $self = shift;
   my $core = shift;
   my $cfg  = $core->get_plugin_cfg($self);

   $self->{min_length} = $cfg->{min_length} || 160;

   eval {
      $self->{bitly} = WebService::Bitly->new(%{$cfg->{creds}});
      register( $self, 'SERVER', 'public_msg' );
      logger->info("Registered");
   };

   if (my $err = $@) {
      logger->warn("Unable to create WebService::Bitly object: $err");
   }

   return PLUGIN_EAT_NONE;
}

sub Cobalt_unregister {
   my $self = shift;
   my $core = shift;

   logger->info("Unregistered");

   return PLUGIN_EAT_NONE;
}

sub Bot_public_msg {
   my $self = shift;
   my $core = shift;
   my $msg  = ${ shift() };

   my @url = grep { 
      length($_) >= $self->min_length 
   } ( URI::Find::Simple::list_uris( $msg->message ) );

   foreach my $url (@url) {
      my $short = $self->bitly->shorten($url);

      if ($short->is_error) {
         logger->warn("Bitly error: " . $short->status_txt);
         next;
      }

      broadcast( 'message', $msg->context, $msg->channel, $short->short_url );
   }

   return PLUGIN_EAT_NONE;
}

1;
__END__

=pod

=head1 SYNOPSIS

   ## In plugins.conf
   Bitly:
      Module: Bot::Cobalt::Plugin::Bitly
      Opts:
         min_length: <minumum URL length> # default 160
         creds:
            user_name:        <bit.ly user name>
            user_api_key:     <bit.ly user api key>
            end_user_name:    <bit.ly end-user name>    # optional
            end_user_api_key: <bit.ly end-user api key> # optional
            domain:           <domain name to use>      # optional

=head1 DESCRIPTION

A L<Bot::Cobalt> plugin.

Automatically takes any URLs in a given message, and if they are too long,
shortens them via the bit.ly webservice (L<WebService::Bitly>), and then 
broadcasts the newly shortened URL to the channel.

=head1 SEE ALSO

L<WebService::Bitly>

