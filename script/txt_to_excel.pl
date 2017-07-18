#!/usr/bin/perl

# csv2xls: Convert csv to xls
#	   (m)'15 [08 Dec 2015] Copyright H.M.Brand 2007-2016

use strict;
use warnings;

our $VERSION = "1.75";

sub usage
{
    my $err = shift and select STDERR;
    print <<EOU;
usage: txt_to_excel.pl [-s <sep>] [-q <quot>] [-w <width>] [-d <dtfmt>]
               [-o <xls>] [file.csv]
       -s <sep>   use <sep>   as seperator char, auto-detect, default = ','
                  The string "tab" is allowed.
       -e <esc>   use <esc>   as escape    char, auto-detect, default = '"'
                  The string "undef" is allowed.
       -q <quot>  use <quot>  as quotation char,              default = '"'
                  The string "undef" will disable quotation.
       -w <width> use <width> as default minimum column width 
      
       -W <width> default = 2.78cm

       -o <xlsx>   write output to file named <xlsx>, defaults
                  to input file name with .csv replaced with .xls
                  if from standard input, defaults to csv2xls.xls
       -F         allow formula's. Otherwise fields starting with
                  an equal sign are forced to string
       -f         force usage of <xls> if already exists (unlink before use)
       -d <dtfmt> use <dtfmt> as date formats.   Default = 'dd-mm-yyyy'
       -C <C:fmt> use <fmt> as currency formats for currency <C>, no default
       -D cols    only convert dates in columns <cols>. Default is everywhere.
       -u         CSV is UTF8
       -v [<lvl>] verbosity (default = 1)
       -r [row]   row number for header to colored,default = 0
       -b <bg_color>  default = 27
       -n <name>   worksheet name separated by comma
       -t <font>  font [ default : Arial ]
example: txt_to_excel.pl  -s tab  in.csv 

EOU
    exit $err;
    } # usage

use Getopt::Long qw(:config bundling nopermute passthrough);
my $sep;	# Set after reading first line in a flurry attempt to auto-detect
my $quo = '"';
my $esc = '"';
my $wdt = 2.78;	# Default minimal column width
my $xls;	# Excel out file name
my $frc = 0;	# Force use of file
my $utf = 0;	# Data is encoded in Unicode
my $frm = 0;	# Allow formula's
my $dtf = "dd-mm-yyyy";	# Date format
my $crf = "";	# Currency format, e.g.: $:### ### ##0.00
my $opt_v = 1;
my $dtc;
my $row_num=0;
my $width=2.78;
my $bg_color=27;
my $name;
my $font="Arial";
die usage(1) unless @ARGV;
GetOptions (
    "help|h|?"	=> sub { usage (0); },

    "c|s=s"	=> \$sep,
    "q=s"	=> \$quo,
    "e=s"	=> \$esc,
    "w=i"	=> \$wdt,
    "o|x=s"	=> \$xls,
    "d=s"	=> \$dtf,
    "D=s"	=> \$dtc,
    "C=s"	=> \$crf,
    "f"		=> \$frc,
    "F"		=> \$frm,
    "u"		=> \$utf,
    "v:1"	=> \$opt_v,
    "r=i"      => \$row_num,
    "W=f"       => \$width,
    "b=s"       => \$bg_color,
    "n=s"       => \$name,
    "t=s"       => \$font,
    ) or usage (1);

my $title = @ARGV && -f $ARGV[0] ? $ARGV[0] : "csv2xls";
($xls ||= $title) =~ s/(?:\.([a-z]+))?$/.xlsx/i;
my @name;
@name=split /,/,$name if $name;
-s $xls && $frc and unlink $xls;
if (-s $xls) {
    print STDERR "File '$xls' already exists. Overwrite? [y/N] > N\b";
    scalar <STDIN> =~ m/^[yj](es|a)?$/i or exit;
    }

# Don't split ourselves when modules do it _much_ better, and follow the standards
use Text::CSV_XS;
use Date::Calc qw( Delta_Days Days_in_Month );
use Excel::Writer::XLSX;
use Encode qw( from_to );
use File::Basename qw /basename/;

my $wbk = Excel::Writer::XLSX->new ($xls);
for my $i(0 .. $#ARGV){
	&fun($i);
}

sub fun{
	my $index=shift @_;
	my $f=$ARGV[$index];
	my $base=basename($f);
	$base=~s/\.[a-z]+$//;
	$base= $name[$index] if $name;
my $wks = $wbk->add_worksheet ($base);
   $dtf =~ s/j/y/g;
my %fmt = (
    date	=> $wbk->add_format (
	num_format	=> $dtf,
	align		=> "center",
	font            => $font,
	size            => 10,
	),

    rest	=> $wbk->add_format (
	align		=> "left",
	font    =>  $font,
	size    => 10,
	),
   
    firstline   => $wbk->add_format (
	bold    	=> 1,
	font    => $font,
	size    => 10,
	bg_color => $bg_color,
	align  => "left",
	),
    );
$crf =~ s/^([^:]+):(.*)/$1/ and $fmt{currency} = $wbk->add_format (
    num_format	=> "$1 $2",
    align	=> "right",
    );

my ($h, $w, @w) = (0, 1); # data height, -width, and default column widths
my $row;
my $firstline;
unless ($sep) { # No sep char passed, try to auto-detect;
    while (<>) {
	m/\S/ or next;	# Skip empty leading blank lines
	$sep = # start auto-detect with quoted strings
	       m/["\d];["\d;]/  ? ";"  :
	       m/["\d],["\d,]/  ? ","  :
	       m/["\d]\t["\d,]/ ? "\t" :
	       # If neither, then for unquoted strings
	       m/\w;[\w;]/      ? ";"  :
	       m/\w,[\w,]/      ? ","  :
	       m/\w\t[\w,]/     ? "\t" :
				  ";"  ;
	    # Yeah I know it should be a ',' (hence Csv), but the majority
	    # of the csv files to be shown comes from fucking Micky$hit,
	    # that uses semiColon ';' instead.
	$firstline = $_;
	last;
	}
    }
my $csv = Text::CSV_XS-> new ({
    sep_char       => $sep eq "tab"   ? "\t"  : $sep,
    quote_char     => $quo eq "undef" ? undef : $quo,
    escape_char    => $esc eq "undef" ? undef : $esc,
    binary         => 1,
    keep_meta_info => 1,
    auto_diag      => 1,
    });
if ($firstline) {
    $csv->parse ($firstline) or die $csv->error_diag ();
    $row = [ $csv->fields ];
    }
if ($opt_v > 3) {
    foreach my $k (qw( sep_char quote_char escape_char )) {
	my $c = $csv->$k () || "undef";
	$c =~ s/\t/\\t/g;
	$c =~ s/\r/\\r/g;
	$c =~ s/\n/\\n/g;
	$c =~ s/\0/\\0/g;
	$c =~ s/([\x00-\x1f\x7f-\xff])/sprintf"\\x{%02x}",ord$1/ge;
	printf STDERR "%-11s = %s\n", $k, $c;
	}
    }

if (my $rows = $dtc) {
    $rows =~ s/-$/-999/;			# 3,6-
    $rows =~ s/-/../g;
    eval "\$dtc = { map { \$_ => 1 } $rows }";
    }
open IN,"<$f" or die $!;
while ($row && @$row or $row = $csv->getline (*IN)) {
    my @row = @$row;
    @row > $w and push @w, ($wdt) x (($w = @row) - @w);
    foreach my $c (0 .. $#row) {
	my $val = $row[$c] // "";
	my $l = length $val;
	$l > ($w[$c] // -1) and $w[$c] = $l;

	if ($utf and $csv->is_binary ($c)) {
	    from_to ($val, "utf-8", "ucs2");
	    $wks->write_unicode ($h, $c, $val);
	    next;
	    }

	if ($csv->is_quoted ($c)) {
	    if ($utf) {
		from_to ($val, "utf-8", "ucs2");
		$wks->write_unicode ($h, $c, $val);
		}
	    else {
		$wks->write_string  ($h, $c, $val);
		}
	    next;
	    }

	if (!$dtc or $dtc->{$c + 1}) {
	    my @d = (0, 0, 0);	# Y, M, D
	    $val =~ m/^(\d{4})(\d{2})(\d{2})$/   and @d = ($1, $2, $3);
	    $val =~ m/^(\d{2})-(\d{2})-(\d{4})$/ and @d = ($3, $2, $1);
	    if ( $d[2] >=    1 && $d[2] <=   31 &&
		 $d[1] >=    1 && $d[1] <=   12 &&
		 $d[0] >= 1900 && $d[0] <= 2199) {
		my $dm = Days_in_Month (@d[0,1]);
		$d[2] <   1 and $d[2] = 1;
		$d[2] > $dm and $d[2] = $dm;
		my $dt = 2 + Delta_Days (1900, 1, 1, @d);
		$wks->write ($h, $c, $dt, $fmt{date});
		next;
		}
	    }
	if ($crf and $val =~ m/^\s*\Q$crf\E\s*([0-9.]+)$/) {
	    $wks->write ($h, $c, $1 + 0, $fmt{currency});
	    next;
	    }

	if (!$frm && $val =~ m/^=/) {
	    $wks->write_string  ($h, $c, $val);
	    }
	else {
	    my $tmpfmt= $h<$row_num ? $fmt{firstline} : $fmt{rest};
	    $wks->write ($h, $c, $val,$tmpfmt);
	    }
	}
    ++$h % 100 or $opt_v && printf STDERR "%6d x %6d\r", $w, $h;
    } continue { $row = undef }
$opt_v && printf STDERR "%6d x %6d\n", $w, $h;
close IN;
#$wks->set_column ($_, $_, $w[$_]) for 0 .. $#w;
$wks->set_column ($_, $_, 4.1*$width) for 0 .. $#w;
}

$wbk->close ();

