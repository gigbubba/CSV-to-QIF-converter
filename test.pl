use Finance::QIF;

my $qif = Finance::QIF->new(type => "Bank");
#my $qif = Finance::QIF->new(type => "CCard");

my %month = ( 
 JAN => 1,
 FEB => 2,
 MAR => 3,
 APR => 4,
 MAY => 5,
 JUN => 6,
 JUL => 7,
 AUG => 8,
 SEP => 9,
 OCT => 10,
 NOV => 11,
 DEC => 12
);

my $year=16;
 
while ( <> ){
  my ( $date,$date2,$payee, $amount) = split ',';   	
  $amount =~ s/\$//;
  $amount *= -1;  #reverse for credit card.
  
  my ($m,$d) = split ' ',$date;
  
  $month = $month{$m};
  
  $qif->add(
    date     => "$month/$d/$year",
    amount   => $amount ,
    payee    => $payee ,
#   memo     => "memo-txt",
#   category => "Advertising/Subliminal"
  );

}
   
print $qif->as_qif ;

