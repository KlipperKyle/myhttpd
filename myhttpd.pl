#!/usr/bin/env perl

use v5.14;
use warnings;

use Cwd qw(abs_path getcwd);
use IO::Socket::IP;

my $port = 8080;
my $server = "myhttpd/0.1";

sub create_server {
  my $server = IO::Socket::IP->new(LocalPort => $port,
			     Type => SOCK_STREAM,
			     ReuseAddr => 1,
			     Listen => SOMAXCONN )
    || die "Can't open a TCP server on port $port: $!\n";
  print "Listening on port $port ...\n";
  return $server;
}

sub accept_connections {
  my $server = shift;
  while (my $client = $server->accept()) {
    dispatch_client($client);
  }
  close($server);
}

sub dispatch_client {
  my $client = shift;
  my ($path, $proto);
  binmode($client, ":crlf");
  while (my $line = <$client> =~ s/\R\z//r) {
    if ($line =~ /^GET\s+(\S+)(\s+(\S+))?/) {
      $path = $1;
      $proto = $3;
    } elsif ($line eq "") {
      break;
    }
  }
  my $response = defined($proto) ? "$proto " : "";
  my $fullpath = abs_path(getcwd() . ($path // ""));
  if (! defined $path) {
    print STDERR "ERROR: 400 Bad Request from " . $client->peerhost . ":" . $client->peerport . "\n";
    $response .= "400 Bad Request\n\n";
  } elsif (-e $fullpath) {
    if (open(my $fh, "<", $fullpath)) {
      print "GET $fullpath from " . $client->peerhost . ":" . $client->peerport . "\n";
      $response .= "200 OK\n\n";
      $response .= do {local $/; <$fh>} // "";
      close($fh);
    } else {
      print STDERR "ERROR: 403 Forbidden: GET $fullpath from " . $client->peerhost . ":" . $client->peerport . "\n";
      $response .= "403 Forbidden\n\n403 Forbidden\n"
    }
  } else {
    print STDERR "ERROR: 404 Not Found: GET $fullpath from " . $client->peerhost . ":" . $client->peerport . "\n";
    $response .= "404 Not Found\n\n404 Not Found\n";
  }
  print $client $response;
  close($client);
}

sub main {
  my $server = create_server();
  accept_connections($server);
}

main();
