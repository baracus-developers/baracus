package Baracus::SqlTFTPd;

###########################################################################
#
# Baracus build and boot management framework
#
# Derived work based on perl package Net::TFTPd
#
#    by Luigino Masarati, <lmasarati at hotmail dot com>
#    Modified by D. Bahi <dbahi at novell dot com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the Artistic License 2.0, as published
# by the Perl Foundation, or the GNU General Public License 2.0
# as published by the Free Software Foundation; your choice.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  Both the Artistic
# Licesnse and the GPL License referenced have clauses with more details.
#
# You should have received a copy of the licenses mentioned
# along with this program; if not, write to:
#
# FSF, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110, USA.
# The Perl Foundation, 6832 Mulderstraat, Grand Ledge, MI 48837, USA.
#
###########################################################################

use 5.006;
use strict;
use warnings;
use IO::Socket;

use Baracus::SqlFS;
use Baracus::Config qw( :vars );

require Exporter;

# modified for supporting small block sizes, O.Z. 15.08.2007
use constant TFTP_MIN_BLKSIZE  => 8;
use constant TFTP_DEFAULT_BLKSIZE => 512;
use constant TFTP_MAX_BLKSIZE  => 65464;
use constant TFTP_MIN_TIMEOUT  => 1;
use constant TFTP_MAX_TIMEOUT  => 60;
use constant TFTP_DEFAULT_PORT => 69;

use constant TFTP_OPCODE_RRQ   => 1;
use constant TFTP_OPCODE_WRQ   => 2;
use constant TFTP_OPCODE_DATA  => 3;
use constant TFTP_OPCODE_ACK   => 4;
use constant TFTP_OPCODE_ERROR => 5;
use constant TFTP_OPCODE_OACK  => 6;

#   Type   Op #     Format without header
#
#          2 bytes    string   1 byte     string   1 byte
#         -------------------------------------------------
#   RRQ/  | 01/02 |  Filename  |   0  |    Mode    |   0  |
#   WRQ   -------------------------------------------------
#          2 bytes    2 bytes       n bytes
#         -----------------------------------
#   DATA  | 03    |   Block #  |    Data    |
#         -----------------------------------
#          2 bytes    2 bytes
#         ----------------------
#   ACK   | 04    |   Block #  |
#         ----------------------
#          2 bytes  2 bytes        string    1 byte
#         ------------------------------------------
#   ERROR | 05    |  ErrorCode |   ErrMsg   |   0  |
#         ------------------------------------------

our %OPCODES = (
	1       => 'RRQ',
	2       => 'WRQ',
	3       => 'DATA',
	4       => 'ACK',
	5       => 'ERROR',
	6       => 'OACK',
	'RRQ'   => TFTP_OPCODE_RRQ,
	'WRQ'   => TFTP_OPCODE_WRQ,
	'DATA'  => TFTP_OPCODE_DATA,
	'ACK'   => TFTP_OPCODE_ACK,
	'ERROR' => TFTP_OPCODE_ERROR,
	'OACK'  => TFTP_OPCODE_OACK
);

my %ERRORS = (
	0 => 'Not defined, see error message (if any)',
	1 => 'File not found',
	2 => 'Access violation',
	3 => 'Disk full or allocation exceeded',
	4 => 'Illegal TFTP operation',
	5 => 'Unknown transfer ID',
	6 => 'File already exists',
	7 => 'No such user',
	8 => 'Option negotiation'
);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use SqlTFTPd ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
	'all' => [ qw( %OPCODES ) ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.01';

our $LASTERROR;

my $debug=0;

#
# Usage: $tftpdOBJ = SqlTFTPd->new( ['SqlFSHandle' => 'SqlFS object'] );
# return the tftpdOBJ object if success or undef if error
#
sub new
{
	# create the future SqlTFTPd object
	my $self = shift;
	my $class = ref($self) || $self;

	# read parameters
	my %cfg = @_;

	return bless {
	    'LocalPort'   => TFTP_DEFAULT_PORT,
	    'Timeout'     => 10,
	    'ACKtimeout'  => 4,
	    'ACKretries'  => 4,
	    'Readable'    => 1,
	    'Writable'    => 1,
	    'CallBack'    => undef,
	    'BlkSize'     => TFTP_DEFAULT_BLKSIZE,
	    'Debug'       => 0,
	    %cfg,         # merge user parameters
	    '_UDPSERVER_' => {},
	    'SqlFSHandle' => {},
	}, $class;
}

# return 1 if success, undef if error
#
sub open
{
    my $self  = shift;

    my %params = (
	'Proto' => 'udp',
	'LocalPort' => $self->{'LocalPort'}
	);

    # bind only to specified address
    if($self->{'LocalAddr'})
    {
	$params{'LocalAddr'} = $self->{'LocalAddr'};
    }

    if(my $udpserver = IO::Socket::INET->new(%params))
    {
#removed for using this module with IO v. 1.2301 under SUSE 10.1, O.Z. 15.08.2007
#	$udpserver->setsockopt(SOL_SOCKET, SO_RCVBUF, 0);
#	$udpserver->setsockopt(SOL_SOCKET, SO_SNDBUF, 0);

	$self->{'_UDPSERVER_'} = $udpserver;
    }
    else
    {
	$LASTERROR = "Error opening socket for listener: $@\n";
	return(undef);
    }
    return 1;
}

sub setSqlFSHandle
{
    my $self = shift;
    my $sqlfsObj = shift;

    $self->{'SqlFSHandle'} = $sqlfsObj;
}

#
# Usage: $tftpdOBJ->waitRQ($timeout);
# return requestOBJ if success, 0 if $timeout elapsed, undef if error
#
sub waitRQ
{
	# the tftpd object
    # my $tftpd = shift;

	my $self  = shift;
	my $class = ref($self) || $self;
    # return bless {}, $class;

	$LASTERROR = '';

	# clone the object
	my $request;
	foreach my $key (keys(%{$self}))
	{
		# everything but '_xxx_'
		$key =~ /^\_.+\_$/ and next;
		$request->{$key} = $self->{$key};
	}

	# use $timeout or default from $tftpdOBJ
	my $Timeout = shift || $request->{'Timeout'};

	my $udpserver = $self->{'_UDPSERVER_'};

	my ($datagram, $opcode, $datain);

	# vars for IO select
	my ($rin, $rout, $ein, $eout) = ('', '', '', '');
	vec($rin, fileno($udpserver), 1) = 1;

	# check if a message is waiting
	if (select($rout=$rin, undef, $eout=$ein, $Timeout))
	{
		# read the message
		if($udpserver->recv($datagram, TFTP_MAX_BLKSIZE + 4))
		{
			# decode the message
			($opcode, $datain) = unpack("na*", $datagram);

			$request->{'_REQUEST_'}{'OPCODE'} = $opcode;

			# get peer port and address
			my($peerport, $peeraddr) = sockaddr_in($udpserver->peername);
			$request->{'_REQUEST_'}{'PeerPort'} = $peerport;
			$request->{'_REQUEST_'}{'PeerAddr'} = inet_ntoa($peeraddr);

			# get filename and transfer mode
			my @datain = split("\0", $datain);

			$request->{'_REQUEST_'}{'FileName'} = shift(@datain);
			$request->{'_REQUEST_'}{'Mode'} = uc(shift(@datain));
			$request->{'_REQUEST_'}{'BlkSize'} = TFTP_DEFAULT_BLKSIZE;
			$request->{'_REQUEST_'}{'LASTACK'} = 0;
			$request->{'_REQUEST_'}{'PREVACK'} = -1;

			if(scalar(@datain) >= 2)
			{
				$request->{'_REQUEST_'}{'RFC2347'} = { @datain };
			}

			return bless $request, $class;
		}
		else
		{
			$! = $udpserver->sockopt(SO_ERROR);
			$LASTERROR = sprintf "Socket RECV error: %s\n", $!;
			return(undef);
		}
	}
	else
	{
		return(0);
	}
}

#
# Usage: $requestOBJ->processRQ();
# return 1 if success, undef if error
#
sub processRQ
{
	# the request object
	my $self = shift;
    my $pxedisabledips  = shift;
    my $pxedeliveredips = shift;

	$LASTERROR = '';

	if(defined($self->newSOCK()))
	{
		if($self->{'_REQUEST_'}{'Mode'} ne 'OCTET')
		{
			#request is not OCTET
			$LASTERROR = sprintf "%s transfer mode is not supported\n", $self->{'_REQUEST_'}{'Mode'};
			$self->sendERR(0, $LASTERROR);
			return(undef);
		}

		# new socket opened successfully
		if($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_RRQ)
		{
			#################
			# opcode is RRQ #
			#################
			if($self->{'Readable'})
			{
				# read is permitted
				if($self->{'_REQUEST_'}{'FileName'} =~ /\.\.[\\\/]/)
				{
					# requested file contains '..\' or '../'
					$LASTERROR = sprintf "Access to '%s' is not permitted to %s\n", $self->{'_REQUEST_'}{'FileName'}, $self->{'_REQUEST_'}{'PeerAddr'};
					$self->sendERR(2);
					return(undef);
				}

				if(defined($self->checkFILE( $pxedisabledips,
                                             $pxedeliveredips )))
				{
					# file is present
					if(defined($self->negotiateOPTS()))
					{
						# RFC 2347 options negotiated
						if(defined($self->openFILE()))
						{
							# file opened for read, start the transfer
							if(defined($self->sendFILE()))
							{
								# file sent successfully
								return(1);
							}
							else
							{
								# error sending file
								return(undef);
							}
						}
						else
						{
							# error opening file
							return(undef);
						}
					}
					else
					{
						# error negotiating options
#						$LASTERROR = "TFTP error 8: Option negotiation\n";
#						$self->sendERR(8);
						return(undef);
					}
				}
				else
				{
					# file not found
					$LASTERROR .= sprintf "File '%s' not found\n", $self->{'_REQUEST_'}{'FileName'};
					$self->sendERR(1);
					return(undef);
				}
			}
			else
			{
				# if server is not readable
				$LASTERROR = "TFTP Error: Access violation\n";
				$self->sendERR(2);
				return(undef);
			}
		}
		elsif($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_WRQ)
		{
			#################
			# opcode is WRQ #
			#################
			if($self->{'Writable'})
			{
                use File::Basename;
				# write is permitted
				if($self->{'_REQUEST_'}{'FileName'} =~ /\.\.[\\\/]/)
				{
					# requested file contains '..\' or '../'
					$LASTERROR = sprintf "Access to '%s' is not permitted to %s\n", $self->{'_REQUEST_'}{'FileName'}, $self->{'_REQUEST_'}{'PeerAddr'};
					$self->sendERR(2);
					return(undef);
				}
                $self->{'_REQUEST_'}{'WRQFileName'} = basename ($self->{'_REQUEST_'}{'FileName'});
				if(!defined($self->checkFILE( $pxedisabledips,
                                              $pxedeliveredips )))
				{
					# RFC 2347 options negotiated
					if(defined($self->openFILE()))
					{
						# file is not present
						if(defined($self->negotiateOPTS()))
						{
							# file opened for write, start the transfer
							if(defined($self->recvFILE()))
							{
								# file received successfully
								return(1);
							}
							else
							{
								# error receiving file
								return(undef);
							}
						}
						else
						{
							# error negotiating options
#							$LASTERROR = "TFTP error 8: Option negotiation\n";
#							$self->sendERR(8);
							return(undef);
						}
					}
					else
					{
						# error opening file
						$self->sendERR(3);
						return(undef);
					}
				}
				else
				{
					# file not found
					$LASTERROR = sprintf "File '%s' already exists\n", $self->{'_REQUEST_'}{'FileName'};
					$self->sendERR(6);
					return(undef);
				}
			}
			else
			{
				# if server is not writable
				$LASTERROR = "TFTP Error: Access violation\n";
				$self->sendERR(2);
				return(undef);
			}
		}
		else
		{
			#################
			# other opcodes #
			#################
			$LASTERROR = sprintf "Opcode %d not supported as request\n", $self->{'_REQUEST_'}{'OPCODE'};
			$self->sendERR(4);
			return(undef);
		}
	}
	else
	{
		return(undef);
	}
}


#
# Usage: $requestOBJ->newSOCK();
# return 1 if success or undef if error
#
sub newSOCK
{
	# the request object
	my $self = shift;

	$LASTERROR = '';

	# set parameters for the new socket
	my %params = (
		'Proto' => 'udp',
		'PeerPort' => $self->{'_REQUEST_'}{'PeerPort'},
		'PeerAddr' => $self->{'_REQUEST_'}{'PeerAddr'}
	);

	# bind only to specified address
	if($self->{'Address'})
	{
		$params{'LocalAddr'} = $self->{'Address'};
	}

	# open socket
	if(my $udpserver = IO::Socket::INET->new(%params))
	{
#removed for using this module with IO v. 1.2301 under SUSE 10.1, O.Z. 15.08.2007
#		$udpserver->setsockopt(SOL_SOCKET, SO_RCVBUF, 0);
#		$udpserver->setsockopt(SOL_SOCKET, SO_SNDBUF, 0);

		$self->{'_UDPSERVER_'} = $udpserver;
		return(1);
	}
	else
	{
		$LASTERROR = "Error opening socket for reply: $@\n";
		return(undef);
	}
}


#
# Usage: $requestOBJ->negotiateOPTS();
# return 1 if success or undef if error
#
sub negotiateOPTS
{
	# the request object
	my $self = shift;

	$LASTERROR = '';

	if($self->{'_REQUEST_'}{'RFC2347'})
	{
		# parse RFC 2347 options if present
		foreach my $option (keys(%{ $self->{'_REQUEST_'}{'RFC2347'} }))
		{
			if(uc($option) eq 'BLKSIZE')
			{
				# Negotiate the blocksize
				if($self->{'_REQUEST_'}{'RFC2347'}{$option} > TFTP_MAX_BLKSIZE or $self->{'_REQUEST_'}{'RFC2347'}{$option} < TFTP_MIN_BLKSIZE)
				{
					$self->{'_REQUEST_'}{'RFC2347'}{$option} = $self->{'BlkSize'};
				}
				else
				{
					$self->{'_RESPONSE_'}{'RFC2347'}{$option} = $self->{'_REQUEST_'}{'RFC2347'}{$option};
					$self->{'BlkSize'} = $self->{'_RESPONSE_'}{'RFC2347'}{$option};
				}
			}
			elsif(uc($option) eq 'TSIZE')
			{
				# Negotiate the transfer size
				if($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_RRQ)
				{
					$self->{'_RESPONSE_'}{'RFC2347'}{$option} = $self->{'FileSize'};
				}
				else
				{
					$self->{'FileSize'} = $self->{'_REQUEST_'}{'RFC2347'}{$option};
				}
			}
			elsif(uc($option) eq 'TIMEOUT')
			{
				# Negotiate the transfer timeout
				if($self->{'_REQUEST_'}{'RFC2347'}{$option} > TFTP_MAX_TIMEOUT or $self->{'_REQUEST_'}{'RFC2347'}{$option} < TFTP_MIN_TIMEOUT)
				{
					$self->{'_RESPONSE_'}{'RFC2347'}{$option} = $self->{'ACKtimeout'};
				}
				else
				{
					$self->{'_RESPONSE_'}{'RFC2347'}{$option} = $self->{'_REQUEST_'}{'RFC2347'}{$option};
					$self->{'ACKtimeout'} = $self->{'_REQUEST_'}{'RFC2347'}{$option};
				}
			}
			else
			{
				# Negotiate other options...
			}
		}

		# post processing
		if($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_WRQ)
		{
			if($self->{'FileSize'} and $self->{'BlkSize'})
			{
				$self->{'_REQUEST_'}{'LASTACK'} = int($self->{'FileSize'} / $self->{'BlkSize'}) + 1;
			}
		}

		# send OACK for RFC 2347 options
		return($self->sendOACK());
	}
	else
	{
		if($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_WRQ)
		{
			# opcode is WRQ: send ACK for datablock 0
			if($self->{'_UDPSERVER_'}->send(pack("nn", TFTP_OPCODE_ACK, 0)))
			{
				return(1);
			}
			else
			{
				$! = $self->{'_UDPSERVER_'}->sockopt(SO_ERROR);
				$LASTERROR = sprintf "Socket SEND error: %s\n", $!;
				return(undef);
			}
		}
		else
		{
			return(1);
		}
	}
}


#
# Usage: $requestOBJ->readFILE(\$data);
# return number of bytes read from file if success or undef if error
#
sub readFILE
{
	my $self = shift;
	my $datablk = shift;

	$LASTERROR = '';

	if($self->{'_REQUEST_'}{'PREVACK'} < $self->{'_REQUEST_'}{'LASTACK'})
	{
		# if requested block is next block, read next block and return bytes read
		my $fh = $self->{'_REQUEST_'}{'_FH_'};
		my $bytes = read($fh, $$datablk, $self->{'BlkSize'});
		if(defined($bytes))
		{
			return($bytes);
		}
		else
		{
			$LASTERROR = sprintf "Error $! reading file '%s'\n", $self->{'_REQUEST_'}{'FileName'};
			return(undef);
		}
	}
	else
	{
		# if requested block is last block, return length of last block
		return(length($$datablk));
	}
}


#
# Usage: $requestOBJ->writeFILE(\$data);
# return number of bytes written to file if success or undef if error
#
sub writeFILE
{
	my $self = shift;
	my $datablk = shift;

	$LASTERROR = '';

	if ($self->{'_REQUEST_'}{'PREVBLK'} > $self->{'_REQUEST_'}{'LASTBLK'})
	{
		# if last block is < than previous block, return length of last block
		return(length($$datablk));
	}
	elsif($self->{'_REQUEST_'}{'LASTBLK'} eq ($self->{'_REQUEST_'}{'PREVBLK'} + 1))
	{
		# if block is next block, write next block and return bytes written
		my $fh = $self->{'_REQUEST_'}{'_FH_'};
		my $bytes = syswrite($fh, $$datablk);
		return($bytes);
	}
	else
	{
		$LASTERROR = sprintf "TFTP Error DATA block %d is out of sequence, expected block was %d\n", $self->{'_REQUEST_'}{'LASTBLK'}, $self->{'_REQUEST_'}{'PREVBLK'} + 1;
		$self->sendERR(5);
		return(undef);
	}
}


#
# Usage: $requestOBJ->sendFILE();
# return 1 if success or undef if error
#
sub sendFILE
{
	my $self = shift;

	while(1)
	{
		if($self->{'_REQUEST_'}{'LASTACK'} < $self->{'_REQUEST_'}{'LASTBLK'})
		{
			my $datablk = 0;
			if(defined($self->readFILE(\$datablk)))
			{
				# read from file successful
				if($self->sendDATA(\$datablk))
				{
					# send to socket successful
					if($self->{'CallBack'})
					{
						&{$self->{'CallBack'}}($self);
					}
				}
				else
				{
					# error sending to socket
					return(undef);
				}
			}
			else
			{
				# error reading from file
				return(undef);
			}
		}
		else
		{
			# transfer completed
			return(1);
		}
	}
}


#
# Usage: $requestOBJ->recvFILE();
# return 1 if success or undef if error
#
sub recvFILE
{
	my $self = shift;

	$LASTERROR = '';

	$self->{'_REQUEST_'}{'LASTBLK'} = 0;
	$self->{'_REQUEST_'}{'PREVBLK'} = 0;

	while(1)
	{
		my $datablk = 0;
		if($self->recvDATA(\$datablk))
		{
			# DATA received
			if(defined($self->writeFILE(\$datablk)))
			{
				# DATA written to file
				my $udpserver = $self->{'_UDPSERVER_'};

				if(defined($udpserver->send(pack("nn", TFTP_OPCODE_ACK, $self->{'_REQUEST_'}{'LASTBLK'}))))
				{
					# sent ACK
					if(length($datablk) < $self->{'BlkSize'})
					{
                        # done with last block close file and cp to sqlfs
                        $self->closeFILE();
                        $self->{'SqlFSHandle'}->store( $self->{'_REQUEST_'}{'WRQFileName'});
                        unlink $self->{'_REQUEST_'}{'WRQFileName'};
                        rmdir $self->{'_REQUEST_'}{'WRQDirName'};
						return(1);
					}
					else
					{
						next;
					}
				}
				else
				{
					$! = $udpserver->sockopt(SO_ERROR);
					$LASTERROR = sprintf "Socket SEND error: %s\n", $!;
					return(undef);
				}
			}
			else
			{
				# error writing data
				return(undef);
			}
		}
		else
		{
			# timeout waiting for data
			return(undef);
		}
	}
}

#
# Usage: $requestOBJ->recvDATA(\$data);
# return 1 if success or undef if error
#
sub recvDATA
{
	my $self = shift;
	my $datablk = shift;

	$LASTERROR = '';

	my ($datagram, $opcode, $datain);

	my $udpserver = $self->{'_UDPSERVER_'};

	# vars for IO select
	my ($rin, $rout, $ein, $eout) = ('', '', '', '');
	vec($rin, fileno($udpserver), 1) = 1;

	# wait for data
	if(select($rout=$rin, undef, $eout=$ein, $self->{'ACKtimeout'}))
	{
		# read the message
		if($udpserver->recv($datagram, $self->{'BlkSize'} + 4))
		{
			# decode the message
			($opcode, $datain) = unpack("na*", $datagram);
			if($opcode eq TFTP_OPCODE_DATA)
			{
				# message is DATA
				$self->{'_REQUEST_'}{'PREVBLK'} = $self->{'_REQUEST_'}{'LASTBLK'};
				($self->{'_REQUEST_'}{'LASTBLK'}, $$datablk) = unpack("na*", $datain);

				if($self->{'CallBack'})
				{
					&{$self->{'CallBack'}}($self);
				}

				return(1);
			}
			elsif($opcode eq TFTP_OPCODE_ERROR)
			{
				# message is ERR
				$LASTERROR = sprintf "TFTP error message: %s\n", $datain;
				return(undef);
			}
			else
			{
				# other messages...
				$LASTERROR = sprintf "Opcode %d not supported waiting for DATA\n", $opcode;
				return(undef);
			}
		}
		else
		{
			$! = $udpserver->sockopt(SO_ERROR);
			$LASTERROR = sprintf "Socket RECV error: %s\n", $!;
			return(undef);
		}
	}
	else
	{
		$LASTERROR = sprintf "Timeout occurred on DATA packet %d\n", $self->{'_REQUEST_'}{'LASTBLK'} + 1;
		return(undef);
	}
}


#
# Usage: $requestOBJ->sendDATA(\$data);
# return 1 if success or undef if error
#
sub sendDATA
{
	my $self = shift;
	my $datablk = shift;

	$LASTERROR = '';

	my $udpserver = $self->{'_UDPSERVER_'};
	my $retry = 0;

	my ($datagram, $opcode, $datain);

	while($retry < $self->{'ACKretries'})
	{
		if($udpserver->send(pack("nna*", TFTP_OPCODE_DATA, $self->{'_REQUEST_'}{'LASTACK'} + 1, $$datablk)))
		{
			# vars for IO select
			my ($rin, $rout, $ein, $eout) = ('', '', '', '');
			vec($rin, fileno($udpserver), 1) = 1;

			# wait for acknowledge
			if(select($rout=$rin, undef, $eout=$ein, $self->{'ACKtimeout'}))
			{
				# read the message
				if($udpserver->recv($datagram, TFTP_MAX_BLKSIZE + 4))
				{
					# decode the message
					($opcode, $datain) = unpack("na*", $datagram);
					if($opcode eq TFTP_OPCODE_ACK)
					{
						# message is ACK
                  # modified for supporting more blocks count than 65535, O.Z. 15.08.2007
						$self->{'_REQUEST_'}{'PREVACK'} = $self->{'_REQUEST_'}{'LASTACK'};
                  if(int(($self->{'_REQUEST_'}{'LASTACK'}+1) % 65536) == unpack("n", $datain)){
                    $self->{'_REQUEST_'}{'LASTACK'}++;
                  };
						return(1);
					}
					elsif($opcode eq TFTP_OPCODE_ERROR)
					{
						# message is ERR
						$LASTERROR = sprintf "TFTP error message: %s\n", $datain;
						return(undef);
					}
					else
					{
						# other messages...
						$LASTERROR = sprintf "Opcode %d not supported as a reply to DATA\n", $opcode;
						return(undef);
					}
				}
				else
				{
					$! = $udpserver->sockopt(SO_ERROR);
					$LASTERROR = sprintf "Socket RECV error: %s\n", $!;
					return(undef);
				}
			}
			else
			{
				$LASTERROR = sprintf "Retry %d - timeout occurred on ACK packet %d\n", $retry, $self->{'_REQUEST_'}{'LASTACK'} + 1;
				$debug and carp($LASTERROR);
				$retry++;
			}
		}
		else
		{
			$! = $udpserver->sockopt(SO_ERROR);
			$LASTERROR = sprintf "Socket SEND error: %s\n", $!;
			return(undef);
		}
	}
}

#
# Usage: $requestOBJ->openFILE()
# returns 1 if file is opened, undef if error
#
sub openFILE
{
	# the request object
	my $self = shift;
    my $rfh;

	$LASTERROR = '';

	if($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_RRQ)
	{
		########################################
		# opcode is RRQ, open file for reading #
		########################################
        if ( -f "$baDir{bfdir}/$self->{'_REQUEST_'}{'FileName'}" ) {

            # open cached file if it exists in ~baracus/bfdir
            if ( not CORE::open( $rfh, "<", "$baDir{bfdir}/$self->{'_REQUEST_'}{'FileName'}" ) ) {
                $LASTERROR = sprintf "Error opening file '%s' for reading\n", $self->{'_REQUEST_'}{'FileName'};
                return(undef);
			}

			$self->{'_REQUEST_'}{'LASTBLK'} = 1 + int($self->{'FileSize'} / $self->{'BlkSize'});
			$self->{'_REQUEST_'}{'_FH_'} = $rfh;
			return 1;
        }
        elsif ($rfh = $self->{'SqlFSHandle'}->readFH( $self->{'_REQUEST_'}{'FileName'}))
		{
			$self->{'_REQUEST_'}{'LASTBLK'} = 1 + int($self->{'FileSize'} / $self->{'BlkSize'});

			# save the filehandle reference...
			$self->{'_REQUEST_'}{'_FH_'} = $rfh;

			return(1);
		}
		else
		{
			$LASTERROR = sprintf "Error opening file '%s' for reading\n", $self->{'_REQUEST_'}{'FileName'};
			return(undef);
		}
	}
	elsif($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_WRQ)
	{
		########################################
		# opcode is WRQ, open file for writing #
		########################################
        use File::Temp qw/ tempdir /;
        my $tdir = tempdir ("baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
        mkdir $tdir, 0755 || die ("Cannot create directory\n");
        $self->{'_REQUEST_'}{'WRQDirName'} = $tdir;
        $self->{'_REQUEST_'}{'WRQFileName'} = "$tdir/$self->{'_REQUEST_'}{'WRQFileName'}";

        my $wfh = $self->{'_REQUEST_'}{'_FH_'};
		if(CORE::open ($wfh, ">", $self->{'_REQUEST_'}{'WRQFileName'}))
		{
			# only OCTET mode, supported set FileHandle to binary mode...
            binmode($wfh);

            $self->{'_REQUEST_'}{'_FH_'} = $wfh;

			return(1);
		}
		else
		{
			$LASTERROR = sprintf "Error opening file '%s' for writing\n", $self->{'_REQUEST_'}{'FileName'};
			return(undef);
		}
	}
	else
	{
		############################
		# other opcodes are errors #
		############################
		$LASTERROR = sprintf "OPCODE %d is not supported\n", $self->{'_REQUEST_'}{'OPCODE'};
		return(undef);
	}
}

#
# Usage: $requestOBJ->closeFILE()
# returns 1 if file is success, undef if error
#
sub closeFILE
{
	my $self = shift;

	$LASTERROR = '';

    if ( -f "$baDir{bfdir}/$self->{'_REQUEST_'}{'FileName'}" )
    {
        # close cached file if it exists in ~baracus/bfdir
		close $self->{'_REQUEST_'}{'_FH_'};
		undef $self->{'_REQUEST_'}{'_FH_'};
		return(1);
	}
    elsif ($self->{'_REQUEST_'}{'_FH_'})
	{
		if($self->{'SqlFSHandle'}->closeFH( $self->{'_REQUEST_'}{'_FH_'} ) )
		{
            undef $self->{'_REQUEST_'}{'_FH_'};
			return(1);
		}
		else
		{
			$LASTERROR = "Error closing filehandle\n";
			return(undef);
		}
	}
	else
	{
		return(1);
	}
}

#
# Usage: $requestOBJ->checkFILE()
# returns FileSize if file is found, undef if file is not found
#
sub checkFILE
{
	# the request object
	my $self = shift;
    my $pxeips_not = shift;  # track IPs for 01-<mac> pxe disabled entries
    my $pxeips_yes = shift;  # track IPs for 01-<mac> pxe enabled  entries

	# requested file
	my $reqfile = $self->{'_REQUEST_'}{'FileName'};

	my $hash = $self->{'SqlFSHandle'}->detail( $reqfile );

    return undef unless (defined $hash);        # no entry

#    if ( $self->{'_REQUEST_'}{'FileName'} =~ m|01-((([0-9a-fA-F]){2}-?){6})| ) {
#        # special logic for PXE boot files served up via TFTP for baracus
#
#        my $mac = $1;
#        $mac =~ s|-|:|g;
#
#        if ( $hash->{'enabled'} ) {
#            # found 01- entry and it is enabled
#            # make sure to remove any _not entry for this ip
#            if ( defined $pxeips_not->{ $self->{'_REQUEST_'}{'PeerAddr'} } ) {
#                undef $pxeips_not->{ $self->{'_REQUEST_'}{'PeerAddr'} } ;
#            }
#            # we will deilver - store the mac for verify build hook
#            $pxeips_yes->{ $self->{'_REQUEST_'}{'PeerAddr'} } = $mac;
#        }
#        else {
#            # found 01- entry and it is disabled
#            # make sure to remove any _yes entry for this ip
#            if ( defined $pxeips_yes->{ $self->{'_REQUEST_'}{'PeerAddr'} } ) {
#                undef $pxeips_yes->{ $self->{'_REQUEST_'}{'PeerAddr'} } ;
#            }
#            # will not deilver - store the mac for 'miss' on request for 'default'
#            $pxeips_not->{ $self->{'_REQUEST_'}{'PeerAddr'} } = $mac;
#
#            $LASTERROR = "Disabled PXE peer " .
#                $self->{'_REQUEST_'}{'PeerAddr'} . " file '" .
#                    $self->{'_REQUEST_'}{'FileName'} . "'\n";
#            return undef;   # entry disabled
#        }
#    }
#    elsif ( $self->{'_REQUEST_'}{'FileName'} =~ m|/default| ) {
#        # special logic for PXE boot files served up via TFTP for baracus
#
#        # if we are serving up the default we need to make sure
#        # that the IP of the requestor is not the same as that
#        # of the 01-<mac> that was 'missing' because it was disabled
#
#        if ( defined $pxeips_not->{ $self->{'_REQUEST_'}{'PeerAddr'} } ) {
#            my $pxename = "01-";
#            $pxename .= $pxeips_not->{ $self->{'_REQUEST_'}{'PeerAddr'} };
#            $pxename =~ s|:|-|g;
#            $LASTERROR = "Refused  PXE peer " .
#                $self->{'_REQUEST_'}{'PeerAddr'} . " file 'default' as $pxename is disabled\n";
#            return undef;
#        }
#    }
#
	return ( $self->{'FileSize'} = $hash->{'binsize'} );
}

#
# Usage: $requestOBJ->sendOACK();
# return 1 for success and undef for error (see $SqlTFTPd::LASTERROR for cause)
#
sub sendOACK
{
	# the request object
	my $self = shift;
	my $udpserver = $self->{'_UDPSERVER_'};
	my $retry = 0;

	$LASTERROR = '';

	my ($datagram, $opcode, $datain);

	while($retry < $self->{'ACKretries'})
	{
		# send oack
		my $data = join("\0", %{ $self->{'_RESPONSE_'}{'RFC2347'} })."\0";
		if($udpserver->send(pack("na*", TFTP_OPCODE_OACK, $data)))
		{
			# opcode is RRQ
			if($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_RRQ)
			{
				# vars for IO select
				my ($rin, $rout, $ein, $eout) = ('', '', '', '');
				vec($rin, fileno($udpserver), 1) = 1;

				# wait for acknowledge
				if(select($rout=$rin, undef, $eout=$ein, $self->{'ACKtimeout'}))
				{
					# read the message
					if($udpserver->recv($datagram, TFTP_MAX_BLKSIZE + 4))
					{
						# decode the message
						($opcode, $datain) = unpack("na*", $datagram);
						if($opcode == TFTP_OPCODE_ACK)
						{
							# message is ACK
							my $lastack = unpack("n", $datain);
							if($lastack)
							{
								# ack is not for block 0... ERROR
								$LASTERROR = sprintf "Received ACK for block %d instead of 0\n", $lastack;
								return(undef);
							}
							return 1;
						}
						elsif($opcode == TFTP_OPCODE_ERROR)
						{
							# message is ERR
							$LASTERROR = sprintf "TFTP error message: %s\n", $datain;
							return(undef);
						}
						else
						{
							# other messages...
							$LASTERROR = sprintf "Opcode %d not supported as a reply to OACK\n", $opcode;
#							$LASTERROR = "TFTP error 8: Option negotiation\n";
							$self->sendERR(8);
							return(undef);
						}
					}
					else
					{
						$! = $udpserver->sockopt(SO_ERROR);
						$LASTERROR = sprintf "Socket RECV error: %s\n", $!;
						return (undef);
					}
				}
				else
				{
					$LASTERROR = sprintf "Retry %d - timeout occurred waiting reply for OACK packet\n", $retry;
					$debug and carp($LASTERROR);
					$retry++;
				}
			}
			elsif($self->{'_REQUEST_'}{'OPCODE'} eq TFTP_OPCODE_WRQ)
			{
				# opcode is WRQ
				return(1);
			}
		}
		else
		{
			$! = $udpserver->sockopt(SO_ERROR);
			$LASTERROR = sprintf "Socket SEND error: %s\n", $!;
			return(undef);
		}
	}
}

#
# Usage: $requestOBJ->sendERR($code, $message);
# returns 1 if success, undef if error
#
sub sendERR
{
	my $self = shift;
	my($errcode, $errmsg) = @_;
	$errmsg or $errmsg = '';

	my $udpserver = $self->{'_UDPSERVER_'};

	if($udpserver->send(pack("nnZ*", 5, $errcode, $errmsg)))
	{
		return(1);
	}
	else
	{
		$! = $udpserver->sockopt(SO_ERROR);
		$LASTERROR = sprintf "Socket SEND error: %s\n", $!;
		return(undef);
	}
}

sub error
{
	return($LASTERROR);
}

# Preloaded methods go here.

1;
__END__

# Below is stub documentation for your module. You better edit it!

=head1 NAME

SqlTFTPd - Perl extension for Trivial File Transfer Protocol Server

=head1 SYNOPSIS

  use strict;
  use SqlTFTPd;
  use SqlFS;

  my $sqlfsOBJ = SqlFS->new('DataSource' => 'dbi:DriverName:etc', 'User' => 'username', 'Password' => 'password')
    or die "Error creating SqlFS filesystem: %s", SqlFS->error;

  my $tftpdOBJ = SqlTFTPd->new('SqlFSHandle' => $sqlfsOBJ)
    or die "Error creating TFTPd listener: %s", SqlTFTPd->error;

  my $tftpRQ = $tftpdOBJ->waitRQ(10)
    or die "Error waiting for TFTP request: %s", SqlTFTPd->error;

  $tftpRQ->processRQ()
    or die "Error processing TFTP request: %s", SqlTFTPd->error;

=head1 DESCRIPTION

C<SqlTFTPd> is a class implementing a simple I<Trivial File Transfer Protocol> server in Perl as described in RFC1350.

C<SqlTFTPd> also supports the TFTP Option Extension (as described in RFC2347), with the following options:

  RFC2348 TFTP Blocksize Option
  RFC2349 TFTP Timeout Interval and Transfer Size Options

C<SqlTFTPd> uses L<SqlFS> to serve it files instead of a traditional filesystem.

=head1 EXPORT

None by default.

=head2 %OPCODES

The %OPCODES tag exports the I<%OPCODES> hash:

  %OPCODES = (
    1       => 'RRQ',
    2       => 'WRQ',
    3       => 'DATA',
    4       => 'ACK',
    5       => 'ERROR',
    6       => 'OACK',
    'RRQ'   => 1,
    'WRQ'   => 2,
    'DATA'  => 3,
    'ACK'   => 4,
    'ERROR' => 5,
    'OACK'  => 6
  );

=head1 Listener constructor

=head2 new()

  $listener = new SqlTFTPd( ['SqlFSHandle' => 'reference to SqlFS object'] [, OPTIONS ] );

or

  $listener = SqlTFTPd->new( ['SqlFSHandle' => 'reference to SqlFS object'] [, OPTIONS ] );

Create a new SqlTFTPd object where 'reference to SqlFS' is the handle for the 'new' SqlFS object to server as the file repository
and OPTIONS are the default server options.

Valid options are:

  Option     Description                                        Default
  ------     -----------                                        -------
  LocalAddr  Interface to bind to (for multi-homed server)          any
  LocalPort  Port to bind server to                                  69
  Timeout    Timeout in seconds to wait for a request                10
  ACKtimeout Timeout in seconds to wait for an ACK packet             4
  ACKretries Maximum number of retries waiting for ACK                4
  Readable   Clients are allowed to read files                        1
  Writable   Clients are allowed to write files                       0
  BlkSize    Minimum blocksize to negotiate for transfers           512
  CallBack   Reference to code executed for each transferred block    -
  Debug      Activates debug mode (verbose)                           0

=head2 CallBack

The CallBack code is called by processRQ method for each tranferred block.

The code receives (into @_ array) a reference to internal I<$request> object.

Example:

  sub callback
  {
    my $req = shift;
    printf "block: %u\/%u\n", $req->{'_REQUEST_'}{'LASTACK'}, $req->{'_REQUEST_'}{'LASTBLK'};
  }

  my $tftpdOBJ = SqlTFTPd->new('SqlFSHandle' => sqlfsOBJ, 'Timeout' => 60, 'CallBack' => \&callback) or die SqlTFTPd->error;

=head1 Listener methods

=head2 waitRQ()

  $request = $listener->waitRQ([Timeout]);

Waits for a client request (RRQ or WRQ) and returns a I<$request> object or I<undef> if timed out.

If I<Timeout> is missing, the timeout defined for I<$listener> object is used instead.

When the method returns, the program should fork() and process the request invoking processRQ() while the parent process should re-start waiting for another request.

=head1 Request methods

=head2 processRQ()

  $ret = $request->processRQ();

Processes a request and returns 1 if success, undef if error.

=head1 AUTHOR

Luigino Masarati, E<lt>lmasarati@hotmail.comE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=head1 SEE ALSO

L<Net::TFTPd>, L<Net::TFTP> and L<DBI>.

=cut
