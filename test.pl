#!/usr/bin/perl
use strict;
use Atol;
my $a=Atol->new(
	port=>'/dev/cu.usbmodem51',
	boudrate=>'57600',
	password => '30'
	);

$a->printline('Чек');
$a->opencheck;
$a->addpay(5, '01', 'Курица гриль' ); #сумма, секция, название
$a->closecheck( 5, '01' ); #  сумма,тип чека
$a->cut; # отрезать 
