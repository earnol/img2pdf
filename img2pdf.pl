#!/usr/bin/perl -w  
use PDF::API2;
use File::Basename;
use IO::Dir;
use Data::Dumper;
use String::Util 'trim';
use Archive::Zip::SimpleZip qw($SimpleZipError);
use Digest::CRC;
use Encode qw(decode encode);
use Encode::Locale;
use DateTime;
use Config;
use Params::Validate::PP; #needed for win32
use Params::Validate::XS; #needed for win32
use DateTime::Locale::en_US;#needed for win32
use DateTime::Locale::ru_UA;#needed for win32
use DateTime::Locale::ru_RU;#needed for win32

my $bookpars = getbookpars($ARGV[0]);
print encode(console_out => decode(locale => Dumper($bookpars)));

# initialize PDF
my $extname = $bookpars->[1].'.pdf';
my $pdf = PDF::API2->new(-file => $extname);
my $ctx = Digest::CRC->new(type=>"crc32"); $ctx->add($extname);
$pdf->preferences(-onecolumn => 1,-displaytitle => 1, -singlepage => 1);
my $dt = DateTime->now();
$pdf->info(
        'Author'       => "\xFE\xFF".encode('UCS-2BE', decode(locale => $bookpars->[3])),
        'CreationDate' => "D:".$dt->format_cldr("yyyyMMddHHmmss")."+01'00'",
        'ModDate'      => "D:".$dt->format_cldr("yyyyMMddHHmmss")."+01'00'",
        'Creator'      => "img2pdf.pl",
        'Producer'     => "\xFE\xFF".encode('UCS-2BE', decode(locale => $bookpars->[4].', '.$bookpars->[5])),
        'Title'        => "\xFE\xFF".encode('UCS-2BE', decode(locale => $bookpars->[2])),
        'Subject'      => "",
        'Keywords'     => "Information, must, be, free."
    );

$d = IO::Dir->new($bookpars->[0]);
if (defined $d) 
{
  my @fd = ();
  while (defined($_ = $d->read)) 
  { 
    next unless (/\.png$/i || /\.tiff$/i || /\.tif$/i || /\.jpg$/i || /\.jpeg$/i || /\.gif$/i);
    push @fd, $_;
  }
  {
    my @f = sort {$a cmp $b} @fd;
    @fd = @f;
  }
  foreach (@fd)
  {
    # Add a page which inherits its attributes from $a4
    my $page = $pdf->page();
    my $img;
    $img = $pdf->image_png($bookpars->[0].$_) if (/\.png$/i);
    $img = $pdf->image_jpeg($bookpars->[0].$_) if (/\.jpg$/i || /\.jpeg$/i);
    $img = $pdf->image_tiff($bookpars->[0].$_) if (/\.tiff$/i || /\.tif$/i);
    $img = $pdf->image_gif($bookpars->[0].$_) if (/\.gif$/i);
    $page->mediabox($img->width, $img->height);
    print  encode(console_out => decode(locale => $bookpars->[0].$_))."\n"; 
    $page->gfx()->image($img, 0, 0, $img->width, $img->height, 1);
  }
  undef $d;
}

$pdf->save();
# Close the file and write the PDF
$pdf->end();
if($Config{osname} eq "linux")
{
  my $z = new Archive::Zip::SimpleZip $ctx->hexdigest.".zip" or die "Cannot create zip file: $SimpleZipError\n" ;
  $z->add($extname);
  $z->close();
  unlink($extname); 
}
sub getbookpars
{
  my ($inpar) = @_;
  my $path = $inpar;
  if(substr($inpar,-1, 1) ne "/")
  {
    $path .= "/";
  }
  else
  {
    $inpar = substr ($inpar,0, length($inpar) - 1);
  }
  my @PARTS = split(/\//, $inpar);
  my $analpart = $PARTS[scalar @PARTS - 1];
  my @APARTS = split(/,/, $analpart);
  my $fname = $APARTS[0];
  my $authors = join(',', @APARTS[1..scalar @APARTS - 3]);
  my $year =  $APARTS[scalar @APARTS - 1];
  my $publisher =  $APARTS[scalar @APARTS - 2];
  return [$path, $analpart, trim($fname), trim($authors), trim($publisher), trim($year)];
}
