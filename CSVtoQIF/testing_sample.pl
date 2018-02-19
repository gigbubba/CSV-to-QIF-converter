use Finance::QIF;

my $qif = Finance::QIF->new(type => "Bank");
 
while ( <> ){
  my ( $date,$date2,$payee, $amount) = split ',';   	

  $amount =~ s/\$//;
  $qif->add(
    date     => $date  ,
    amount   => $amount,
    payee    => $payee ,
#   memo     => "memo-txt",
#   category => "Advertising/Subliminal"
  );

}
   
print $qif->as_qif ;

