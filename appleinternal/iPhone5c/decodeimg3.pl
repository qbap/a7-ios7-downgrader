#!perl -w
# (C)2009 Willem Hengeveld  itsme@xs4all.nl
use strict;
# this script prints all sections found in the .img3 file, and optionally extracts, and
# decrypts the DATA section

sub usage {
    return <<__EOF__
Usage: decodeimg3 [-v] [-o OUTFILE] [-l] [-k XXXX -iv XXXX]
    -v         : increase verbosity level
    -o OUTFILE : save DATA section to OUTFILE
    -l         : don't decrypt the last DATA block ( for 7a341 ipsw )
    -k XX -iv X: specify key + iv when you want to decrypt the DATA section
__EOF__
}

# filetypes: ( * = s5l8900x,s5l8920x  # = m68ap,n82ap,n88ap )
#   bat0 - batterylow0.*.img3
#   bat1 - batterylow1.*.img3
#   batF - batteryfull.*.img3
#   chg0 - batterycharging0.*.img3
#   chg1 - batterycharging1.*.img3
#   dtre - DeviceTree.#.img3
#   glyC - glyphcharging.*.img3
#   glyP - glyphplugin.*.img3
#   ibec - iBEC.#.RELEASE.dfu
#   ibot - iBoot.#.RELEASE.img3
#   ibss - iBSS.#.RELEASE.dfu
#   illb - LLB.#.RELEASE.img3
#   krnl - kernelcache.release.*
#   logo - applelogo.*.img3
#   nsrv - needservice.*.img3
#   recm - recoverymode.*.img3
#   rdsk - {restore/update}.dmg files
#   cert - inside certificates

# tagtypes:
# BORD  : DWORD: 0 or 4
# CERT  : certificate
# DATA  : the encrypted data
#    -  echo <DATA> 00000000000000000000000000000000 | unhex | openssl enc -aes-128-cbc -K d2dad0c5dc935afddd628a2c2c243c4f -iv 1b8a5224f45aa94cfc02a8ceba55d6d8 -d | dump -
# KBAG  : DWORD type,aes, iv, key  - used to calc the iv+key by encrypting with the GID key
# SEPO  : DWORD: 2, 3 or 5
# SHSH  : 128 bytes
# TYPE  : equal to the header filetype
# VERS  : DWORD len + ascii string

# ---- in 'cert' files:
# SDOM  : DWORD  - security domain
# PROD  : DWORD  - product
# CHIP  : DWORD  - chipset
#
use IO::File;
#use WildcardArgs;
use Getopt::Long;
use Crypt::Rijndael;

$|=1;
my $verbose=0;
my $recurse;
my ($aeskey,$aesiv);
my $g_dontdecryptlastblock;
my $outfilename;
GetOptions(
    "v+"=>\$verbose,
#    "r"=>\$recurse,
    "o=s"=>\$outfilename,
    "l"=>\$g_dontdecryptlastblock,
    "k=s"=>sub { $aeskey= pack("H*", $_[1]) },
    "iv=s"=>sub { $aesiv= pack("H*", $_[1]) },
) or die usage();
#handlearg($_, \&processfile, recurse=>$recurse) for @ARGV;

die usage() if !@ARGV;

processfile(shift);

sub processfile {
    my $fn= shift;
    my $fh= IO::File->new($fn, "r");
    if (!$fh) {
        warn "$fn: $!\n";
        return;
    }
    binmode $fh;

    undef $/;
    my $data= <$fh>;
    $fh->close();

    my %hdr;
    (
        $hdr{filemagic},        # 00 'Img3'
        $hdr{filesize},         # 04
        $hdr{contentsize},      # 08
        $hdr{certarea},         # 0c
        $hdr{filetype},         # 10 'illb', 'ibot' ...
    )= unpack("a4VVVa4", $data);
    if ($hdr{filemagic} ne "3gmI") {
        warn "incorrect filemagic: $hdr{filemagic} - $fn\n";
        return;
    }
    if ($hdr{filesize} != length($data)) {
        warn sprintf("header:filesize=%08lx, file:%08lx\n", $hdr{filesize}, length($data));
    }
    if ($hdr{filesize} < $hdr{contentsize}) {
        warn sprintf("filesize < contentsize: %08lx < %08lx\n", $hdr{filesize}, $hdr{contentsize});
        return;
    }
    if ($hdr{contentsize} < $hdr{certarea}) {
        warn sprintf("contentsize < certarea: %08lx < %08lx\n", $hdr{contentsize}, $hdr{certarea});
        return;
    }
    $hdr{filetype}= reverse $hdr{filetype};
    printf("%s - %s\n", $hdr{filetype}, $fn);
    my %sections;
    my $ofs= 20;
    my $datarest="";
    while ($ofs<20+$hdr{contentsize}) {
        my %tag;
        (
            $tag{magic},          # TYPE DATA VERS SEPO BORD KBAG KBAG SHSH CERT 
            $tag{blocksize},
            $tag{payloadsize},
        )= unpack("a4VV", substr($data, $ofs, 12));

        last if $tag{blocksize}==0;
        $tag{magic}= reverse $tag{magic};
        $tag{data}= substr($data, $ofs+12, $tag{payloadsize});
        $tag{rest}= substr($data, $ofs+12+ $tag{payloadsize}, $tag{blocksize} - $tag{payloadsize}-12);

        $sections{$tag{magic}}= $tag{data};

        $datarest = $tag{rest} if $tag{magic} eq 'DATA';

        if ($tag{magic} eq "TYPE") {
            printf("  %s %08x %6x: '%s'\n", $tag{magic}, $ofs+12, $tag{payloadsize}, scalar reverse $tag{data});
        }
        elsif ($tag{magic} eq "SDOM") {
            printf("  %s %08x %6x: 0x%x\n", $tag{magic}, $ofs+12, $tag{payloadsize}, unpack("V", $tag{data}));
        }
        elsif ($tag{magic} eq "PROD") {
            printf("  %s %08x %6x: 0x%x\n", $tag{magic}, $ofs+12, $tag{payloadsize}, unpack("V", $tag{data}));
        }
        elsif ($tag{magic} eq "CHIP") {
            printf("  %s %08x %6x: 0x%x\n", $tag{magic}, $ofs+12, $tag{payloadsize}, unpack("V", $tag{data}));
        }
        elsif ($tag{magic} eq "BORD") {
            printf("  %s %08x %6x: 0x%02lx\n", $tag{magic}, $ofs+12, $tag{payloadsize}, unpack("V", $tag{data}));
        }
        elsif ($tag{magic} eq "SEPO") {
            printf("  %s %08x %6x: 0x%02lx\n", $tag{magic}, $ofs+12, $tag{payloadsize}, unpack("V", $tag{data}));
        }
        elsif ($tag{magic} eq "KBAG") {
            my ($ivtype, $aes, $iv, $key)= unpack("VVa16a*", $tag{data});
            printf("  %s %08x %6x: %d %3d %s %s\n", $tag{magic}, $ofs+12, $tag{payloadsize}, $ivtype, $aes, unpack("H*",$iv), unpack("H*",$key));
        }
        elsif ($tag{magic} eq "VERS") {
            printf("  %s %08x %6x: 0x%02lx '%s'\n", $tag{magic}, $ofs+12, $tag{payloadsize}, unpack("Va*",$tag{data}));
        }
        else {
            printf("  %s %08x %6x: %s%s\n", $tag{magic}, $ofs+12, $tag{payloadsize}, unpack("H*", substr($tag{data}, 0, $tag{payloadsize}<32?$tag{payloadsize}:32)), $tag{payloadsize}>32?"...":"");
        }
        $ofs += $tag{blocksize};
    }
    if ($ofs != 20+$hdr{contentsize}) {
        printf("ofs=%08lx, expected: %08lx\n", $ofs, 20+$hdr{contentsize});
    }

    if ($aeskey && $aesiv) {
        my $encdata= $sections{DATA}.$datarest;
        $encdata .= "\x00" x (16-(length($encdata)%16)) if (length($encdata)%16);
        my $decrypted= aesdecrypt($encdata, $aeskey, $aesiv);
        my $restsize= length($encdata)-length($sections{DATA});
        my $hexsize= $restsize;
        $hexsize += (16-($restsize%16)) if($restsize%16);
        printf("last[%2d]: org:%s  dec:%s\n", $restsize, unpack("H*", substr($encdata,-$hexsize)), unpack("H*", substr($decrypted, -$hexsize))) if ($hexsize);

        substr($decrypted, -16, 16)=  substr($encdata,-16,16) if $g_dontdecryptlastblock;

        if ($outfilename) {
            my $ofh= IO::File->new($outfilename, "w") or die "$outfilename: $!\n";
            binmode $ofh;
            $ofh->print(substr($decrypted, 0, length($sections{DATA})));
            $ofh->close();
        }
        else {
            printf("decrypted: %s\n", unpack("H*", substr($decrypted, 0, 256)));
        }
    }
    elsif ($outfilename) {
        my $ofh= IO::File->new($outfilename, "w") or die "$outfilename: $!\n";
        binmode $ofh;
        $ofh->print(substr($sections{DATA}, 0, length($sections{DATA})));
        $ofh->close();
    }
    elsif (exists $sections{DATA}) {
        my $encdata= $sections{DATA}.$datarest;

        my $hexsize= length($datarest);
        $hexsize += (16-($hexsize%16)) if($hexsize%16);
        printf("last[%2d]: org:%s\n", length($datarest), unpack("H*", substr($encdata,-$hexsize))) if ($hexsize);
    }
}
sub aesdecrypt {
    my ($encdata, $key, $iv)= @_;
    my $aes= Crypt::Rijndael->new($key);
    my $decdata= "";

    for (my $ofs=0 ; $ofs<length($encdata) ; $ofs+=16)
    {
        my $ciph= substr($encdata,$ofs,16);
        my $decr= $aes->decrypt($ciph) ^ $iv;
        $decdata .= $decr;
        $iv= $ciph;
    }
    return $decdata;
}
