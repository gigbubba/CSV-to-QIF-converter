package Finance::QIF;

use 5.006;
use strict;
use warnings;
use Carp;
use overload '""' => \&as_qif;

our $VERSION = '1.03';

=head1 NAME

Finance::QIF - Parse and create Quicken Interchange Format files

=head1 SYNOPSIS

  use Finance::QIF;

=head2 Parsing existing QIFs

  my $qif = Finance::QIF->parse_file("foo.qif");
  $qif = Finance::QIF->parse("foo.qif");

  for my $entry ($qif->transactions) {
    print $entry->payee, ": ", $entry->amount,"\n";
  }

=head2 Exporting data as QIF

  my $qif = Finance::QIF->new(type => "Bank");
  $qif->add($transaction);
  $qif->add(
    amount   => -50.00,
    payee    => "Simon Cozens",
    memo     => "We really should have given him more for producing all these 
                 cool modules",
    date     => "12/19/2002",
    category => "Advertising/Subliminal"
  );

  print $qif->as_qif;
  print $qif; # Stringification is overloaded too

=head1 DESCRIPTION

This module handles and creates files in Intuit's Quicken Interchange
Format. A spec for this format can be found at
L<http://www.respmech.com/mym2qifw/qif_new.htm>; this implementation is
liberal in terms of date formats, doing no date checking and simply
passing on whatever it receives.

=head1 METHODS

=head2 new(type => "Bank")

Create a new, blank QIF object. A type must be specified, but for this
release, the only thing we support is "Bank" accounts, since I'm not
wise enough to have investment accounts yet and so don't need that
functionality.

=cut



sub new {
    my ($class, %args) = @_;
    die " \nCan only deal with bank accounts right now\n "    unless $args{type} eq "Bank";
    my $self = bless \%args, $class;
    $self->{transactions} = [];
    return $self;
}

=head2 as_qif()

Returns the QIF object as a string in QIF format.

=cut

sub as_qif {
    my $self = shift;
    my $out ="!Type:$self->{type}\n";
    $out .= $_->as_qif."^\n" for @{$self->{transactions}};
    return $out;
}

=head2 add

Adds a new transaction; this may be a C<Finance::QIF::Transaction>
object (see below) or a hash.

=cut

sub add {
    my $self = shift;
    push @{$self->{transactions}}, 
        (ref $_[0] and $_[0]->isa("Finance::QIF::Transaction")) ?
            shift
        :
         (Finance::QIF::Transaction->new(@_));
}

=head2 parse_file

Creates a C<Finance::QIF> object from an existing file.

=cut

sub parse_file {
    my ($class, $file) = @_;
    local $/; open my $f, $file or croak $!; my $data = <$f>;
    return $class->parse($data);
}

=head2 parse

Creates a C<Finance::QIF> object from a string.

=cut

sub parse {
    my ($class, $data) = @_;
    my @lines = split /[\r\n]/, $data;
    my $type = shift @lines;
    croak "Can only handle bank accounts right now, not type $type"
        unless $type eq "!Type:Bank";
    my $self = new Finance::QIF (type => "Bank");
    my $entry = Finance::QIF::Transaction->new();
    my $lineno = 1;
    while (my $line = shift @lines) {
        $lineno++;
        $line =~ s/^(.)//; my $thing = $1;
        if ($thing =~ /[DTCNPML]/) {
            my $method = $Finance::QIF::Transaction::qkeys{$thing};
            die "Something went wrong with $thing!" unless $method;
            $entry->$method($line);
        } elsif ($thing eq "^") {
            $self->add($entry);
            $entry = new Finance::QIF::Transaction;
        } elsif ($thing eq "A") {
            $lineno++, ($line .= shift @lines) while $lines[0] =~ s/^A//;
            $entry->address($line);
        } elsif ($thing eq 'S') {
            my $split = {category => $line};
            $lineno++, ($split->{memo} = shift @lines) if $lines[0]=~s/^E//;
            carp "Broken split - no split amount seen at line $lineno"
                unless $lines[0]=~ s/^\$//;
            $split->{amount} = shift @lines; $lineno++;
            $entry->add_to_splits($split);
        } else {
            carp "Unknown QIF field '$thing' at line $lineno"; 
        }
    }
    return $self;
}

=head2 transactions

Returns a list of C<Finance::QIF::Transaction>s. See below.

=cut 

sub transactions { return @{$_[0]->{transactions}}}
1;

=head1 Finance::QIF::Transaction

Individual transactions are objects of the class
C<Finance::QIF::Transaction>. These objects will be returned from the
C<transactions> method on a C<Finance::QIF> object, and can be created,
queried and modified with the following methods.

=cut

package Finance::QIF::Transaction;
use Carp;

=head2 new

Creates a new transaction object and populates it with data.

=cut


sub new { 
    my $class = shift; bless { @_ }, $class;
}

=head2 amount

Gets/sets the transaction's amount. No currency is implied. The amount
is always returned as a string formatted to two decimal places.

REMEMBER that outgoing transactions should always be specified as a
negative amount.

=cut

sub amount { 
  my $self = shift; 
  if (defined $_[0] )
  {
    $self->{amount} = $_[0];
    $self->{amount} =~ s/,// ;     
  }
    
  $self->{amount} = 0 if !$self->{amount} ;
  return sprintf("%.2f",$self->{amount});
}

=head2 date / payee / memo / address / category / cleared / number

These are ordinary get-set methods for the specified fields. "Number" in
QIF refers to a check or reference number.

=head2 splits

Gets and sets an array of split values each specified as a hash
reference. For example:

    $item->amount(-30);
    $item->payee("Cash withdrawal");
    $item->splits(
        { category => "Food/Groceries", amount => 12.00 },
        { category => "Stationery",     amount => 5.00  },
        { category => "Dining Out",     amount => 13.00 }
    )

=cut

for (qw[ date payee memo address category cleared number ]) {
    eval <<EOF
sub $_ {
    my \$self = shift; \$self->{$_} = \$_[0] if defined \$_[0];
    \$self->{$_} =~ s/\\n/ /g;
    return \$self->{$_};
}
EOF
}

sub splits {
    my $self = shift;
    if (@_) {
        $self->{splits} = [];
        $self->add_to_splits($_) for @_;
    }
    return @{ $self->{splits} || [] };
}

=head2 add_to_splits

Adds a split entry (as a hash reference) to the split list. This does
not affect the amount of the transaction.

    $item->add_to_splits(
        { category => "Dining Out",     amount => 13.00 }
    );

=cut

sub add_to_splits {
    my $self = shift;
    my %split = %{$_[0]};
    $self->{splits} = [] unless exists $self->{splits};
    $split{$_} ||= "" for qw(memo category amount);
    for (keys %split) {
        croak "Illegal split key $_" unless /^(memo|category|amount)/;
    }
    push @{$self->{splits}}, \%split;
}

=head2 as_qif

Returns the transaction in QIF format.

=cut

our %qkeys = (
    D => "date",
    T => "amount",
    C => "cleared",
    N => "number",
    P => "payee",
    M => "memo",
    L => "category"
);

sub as_qif {
    my $out;
    my $self = shift;
    # Address and splits need special treatment
    for (keys %qkeys) {
        my $meth = $qkeys{$_};
        next unless defined $self->{$meth};
        $out .= $_.($self->$meth)."\n" 
    }
    if (defined $self->{address}) {
        for ((split("\n", $self->{address}))[0..4]) {
            $out.= "A$_\n";
        }
    }
    if (ref $self->{splits}) {
        for (@{$self->{splits}}) {
            $out .= "S". $_->{category}."\n";
            $out .= "E". $_->{memo}."\n" if defined $_->{memo};
            $out .= '$'. $_->{amount}."\n";
        }
    }
    return $out;
}





=head1 LICENSE 

Copyright (c) 2004 by Nathan McFarland. All rights reserved. This program
is free software; you may redistribute it and or modify it under the terms 
of the Artistic license.


=head1 MAINTAINER 

Nathan McFarland, C<nmcfarl@cpan.org>

=head1 ORIGINAL AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 SEE ALSO

L<perl>.

=cut

