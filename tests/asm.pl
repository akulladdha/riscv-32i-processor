#!/usr/bin/perl
# Minimal RV32I assembler -> hex words, one per line, for $readmemh.
# Usage: perl tests/asm.pl input.s output.hex
#
# Supports the RV32I subset this repo tests. Two passes: labels, then encode.
# Syntax:  label:            add x1, x2, x3      addi x1, x2, -5
#          lw x1, 8(x2)      sw x1, 8(x2)        beq x1, x2, label
#          lui x1, 0x12345   jal x1, label       jalr x1, x2, 0
#          nop               fence               ecall / ebreak
use strict;
use warnings;

my ($src, $dst) = @ARGV;
die "usage: asm.pl in.s out.hex\n" unless $src && $dst;

my %R = (ADD =>['0000000','000'], SUB =>['0100000','000'], SLL=>['0000000','001'],
         SLT =>['0000000','010'], SLTU=>['0000000','011'], XOR=>['0000000','100'],
         SRL =>['0000000','101'], SRA =>['0100000','101'], OR =>['0000000','110'],
         AND =>['0000000','111']);
my %I = (ADDI=>'000', SLTI=>'010', SLTIU=>'011', XORI=>'100', ORI=>'110', ANDI=>'111');
my %SH= (SLLI=>['0000000','001'], SRLI=>['0000000','101'], SRAI=>['0100000','101']); # [funct7, funct3]
my %L = (LB=>'000', LH=>'001', LW=>'010', LBU=>'100', LHU=>'101');
my %S = (SB=>'000', SH=>'001', SW=>'010');
my %B = (BEQ=>'000', BNE=>'001', BLT=>'100', BGE=>'101', BLTU=>'110', BGEU=>'111');

sub reg {
    my $r = shift;
    $r =~ s/^\s+|\s+$//g;
    die "bad register '$r'\n" unless $r =~ /^x(\d+)$/i && $1 < 32;
    return $1;
}
sub imm {
    my $v = shift;
    $v =~ s/^\s+|\s+$//g;
    my $neg = ($v =~ s/^-//) ? 1 : 0;
    my $n = ($v =~ /^0x/i) ? hex($v) : ($v =~ /^\d+$/ ? $v + 0 : die "bad immediate '$v'\n");
    return $neg ? -$n : $n;
}
sub bits { my ($v,$n) = @_; return sprintf("%0*b", $n, $v & ((1 << $n) - 1)); }
sub slice { my ($v,$hi,$lo) = @_; return bits(($v >> $lo), $hi - $lo + 1); }

# ---- pass 1: labels ----
open(my $in, '<', $src) or die "cannot open $src: $!\n";
my @lines; my %label; my $pc = 0;
while (my $l = <$in>) {
    $l =~ s/[#;].*$//;            # strip comments
    $l =~ s/^\s+|\s+$//g;
    next unless length $l;
    while ($l =~ s/^(\w+):\s*//) { $label{$1} = $pc; }
    next unless length $l;
    push @lines, [$pc, $l];
    $pc += 4;
}
close $in;

# ---- pass 2: encode ----
my @out;
for my $e (@lines) {
    my ($addr, $l) = @$e;
    my ($op, $rest) = split(/\s+/, $l, 2);
    $op = uc $op;
    $rest = '' unless defined $rest;
    my @a = map { s/^\s+|\s+$//gr } split(/,/, $rest);
    my $w;

    if    ($op eq 'NOP')    { $w = '00000000000000000000000000010011'; }
    elsif ($op eq 'FENCE')  { $w = '0000' . '1111' . '1111' . '00000' . '000' . '00000' . '0001111'; }
    elsif ($op eq 'ECALL')  { $w = bits(0,12) . '00000' . '000' . '00000' . '1110011'; }
    elsif ($op eq 'EBREAK') { $w = bits(1,12) . '00000' . '000' . '00000' . '1110011'; }
    elsif (exists $R{$op}) {
        my ($f7,$f3) = @{$R{$op}};
        $w = $f7 . bits(reg($a[2]),5) . bits(reg($a[1]),5) . $f3 . bits(reg($a[0]),5) . '0110011';
    }
    elsif (exists $I{$op}) {
        $w = bits(imm($a[2]),12) . bits(reg($a[1]),5) . $I{$op} . bits(reg($a[0]),5) . '0010011';
    }
    elsif (exists $SH{$op}) {
        my ($f7,$f3) = @{$SH{$op}};
        my $sh = imm($a[2]) & 0x1f;
        $w = $f7 . bits($sh,5) . bits(reg($a[1]),5) . $f3 . bits(reg($a[0]),5) . '0010011';
    }
    elsif (exists $L{$op}) {
        die "bad load operand '$a[1]'\n" unless $a[1] =~ /^(-?\w+)\((x\d+)\)$/i;
        my ($off,$base) = (imm($1), reg($2));
        $w = bits($off,12) . bits($base,5) . $L{$op} . bits(reg($a[0]),5) . '0000011';
    }
    elsif (exists $S{$op}) {
        die "bad store operand '$a[1]'\n" unless $a[1] =~ /^(-?\w+)\((x\d+)\)$/i;
        my ($off,$base) = (imm($1), reg($2));
        $w = slice($off,11,5) . bits(reg($a[0]),5) . bits($base,5) . $S{$op} . slice($off,4,0) . '0100011';
    }
    elsif (exists $B{$op}) {
        my $t = exists $label{$a[2]} ? $label{$a[2]} - $addr : imm($a[2]);
        $w = substr(bits($t,13),0,1) . slice($t,10,5) . bits(reg($a[1]),5) . bits(reg($a[0]),5)
           . $B{$op} . slice($t,4,1) . substr(bits($t,12),0,1) . '1100011';
    }
    elsif ($op eq 'LUI' || $op eq 'AUIPC') {
        my $opc = ($op eq 'LUI') ? '0110111' : '0010111';
        $w = bits(imm($a[1]),20) . bits(reg($a[0]),5) . $opc;
    }
    elsif ($op eq 'JAL') {
        my $t = exists $label{$a[1]} ? $label{$a[1]} - $addr : imm($a[1]);
        $w = substr(bits($t,21),0,1) . slice($t,10,1) . slice($t,11,11) . slice($t,19,12)
           . bits(reg($a[0]),5) . '1101111';
    }
    elsif ($op eq 'JALR') {
        $w = bits(imm($a[2]),12) . bits(reg($a[1]),5) . '000' . bits(reg($a[0]),5) . '1100111';
    }
    else { die "unknown instruction '$op' at 0x" . sprintf("%x", $addr) . "\n"; }

    die "internal: '$op' produced " . length($w) . " bits\n" unless length($w) == 32;
    push @out, sprintf("%08X", oct("0b$w"));
}

open(my $o, '>', $dst) or die "cannot write $dst: $!\n";
print $o "$_\n" for @out;
close $o;
print "assembled " . scalar(@out) . " instructions -> $dst\n";
