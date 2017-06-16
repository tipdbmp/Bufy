unit module Bufy;

constant u8 is export(:constants) = uint8;
constant u16 is export(:constants) = uint16;
constant u32 is export(:constants) = uint32;
constant u64 is export(:constants) = uint64;

constant i8 is export(:constants) = int8;
constant i16 is export(:constants) = int16;
constant i32 is export(:constants) = int32;
constant i64 is export(:constants) = int64;

constant f32 is export(:constants) = num32;
constant f64 is export(:constants) = num64;

# byte
# uint
# int
# num
# str

class Serializable is export(:Serializable) {}

my SetHash $attr-is-no-serialize; BEGIN { $attr-is-no-serialize = SetHash.new; }
multi sub trait_mod:<is>(Attribute $a, :$no-serialize) is export(:no-serialize) {
    $attr-is-no-serialize{$a.WHICH.Str} = True;
}
sub attr-is-no-serialize(Attribute $a --> Bool) { $attr-is-no-serialize{$a.WHICH.Str} }

# @Fixme: these functions create unnecessary intermediate arrays,
# find a better way to reinterpret f64/32 to u64/32
#
use NativeCall;

sub f64-as-u64(f64 $x --> u64) is export(:f64-as-u64, :functions) {
    nativecast(CArray[u64], CArray[f64].new($x))[0]
}
sub u64-as-f64(u64 $x --> f64) is export(:u64-as-f64, :functions) {
    nativecast(CArray[f64], CArray[u64].new($x))[0]
}
sub f32-as-u32(f32 $x --> u32) is export(:f32-as-u32, :functions) {
    nativecast(CArray[u32], CArray[f32].new($x))[0]
}
sub u32-as-f32(u32 $x --> f32) is export(:u32-as-f32, :functions) {
    nativecast(CArray[f32], CArray[u32].new($x))[0]
}

sub write-type(buf8 $b, Any:D $x) is export(:write-type, :functions) {
    my Any $ty = $x.WHAT;

    {
        my $version = $ty.^lookup('version');
        if defined($version) {
            write-u8($b, $ty.$version());
        }
    }

    for $ty.^attributes -> $attr {
        next if attr-is-no-serialize($attr);

        given $attr.type {

        when u64 { write-u64($b, $attr.get_value($x)); }
        when u32 { write-u32($b, $attr.get_value($x)); }
        when u16 { write-u16($b, $attr.get_value($x)); }
        when u8 { write-u8($b, $attr.get_value($x)); }

        when i64 { write-i64($b, $attr.get_value($x)); }
        when i32 { write-i32($b, $attr.get_value($x)); }
        when i16 { write-i16($b, $attr.get_value($x)); }
        when i8 { write-i8($b, $attr.get_value($x)); }

        when f64 { write-f64($b, $attr.get_value($x)); }
        when f32 { write-f32($b, $attr.get_value($x)); }

        # when Int { write-Int($b, $attr.get_value($x)); }
        when Str { write-Str($b, $attr.get_value($x)); }

        # when Array | array {
        when Positional {
            my $array_of = $attr.type.of;
            my $array = $attr.get_value($x);
            write-array($b, $array_of, $array);
        }

        when Serializable { write-type($b, $attr.get_value($x)); }

        default { die X::AdHoc.new(payload => 'write-type: unsupported type: ' ~ $_.^name); }
        } # given
    }
}

sub write-array(buf8 $b, Any:U $ty, @array) is export(:write-array, :functions) {
    write-u32($b, @array.elems);

    given $ty {

    when u64 { for @array ->$e { write-u64($b, $e); } }
    when u32 { for @array ->$e { write-u32($b, $e); } }
    when u16 { for @array ->$e { write-u16($b, $e); } }
    when u8 { for @array ->$e { write-u8($b, $e); } }

    when i64 { for @array ->$e { write-i64($b, $e); } }
    when i32 { for @array ->$e { write-i32($b, $e); } }
    when i16 { for @array ->$e { write-i16($b, $e); } }
    when i8 { for @array ->$e { write-i8($b, $e); } }

    when f64 { for @array -> $e { write-f64($b, $e); } }
    when f32 { for @array -> $e { write-f32($b, $e); } }

    # when Int { for @array ->$e { write-Int($b, $e); } }
    when Str { for @array ->$e { write-Str($b, $e); } }

    when Serializable { for @array ->$e { write-type($b, $e); } }

    default { die X::AdHoc.new(payload => 'write-array: unsupported type: ' ~ $ty.^name); }
    } # given
}

sub read-type(buf8 $b, Any:U $ty is copy, u64 $offset is rw --> Any)
    is export(:read-type, :functions) {
    my Any $result;

    {
        my $version = $ty.^lookup('version');
        if defined($version) {
            my $our_v = $ty.$version();
            my u8 $given_v = read-u8($b, $offset);

            if $given_v > $our_v {
                fail "found version $given_v but {$ty.^name} is only at version $our_v";
            }

            my Str $ty_v = "{$ty.^name}_{sprintf('0x%02X', $given_v)}"; # Foo_0x02

            # ::(<type-name>) throws an exception if $ty_name is not declared
            $ty = ::($ty_v);
        }
    }

    $result = $ty.CREATE;

    for $ty.^attributes -> $attr {
        next if attr-is-no-serialize($attr);

        given $attr.type {

        when u64 { $attr.set_value($result, read-u64($b, $offset)); }
        when u32 { $attr.set_value($result, read-u32($b, $offset)); }
        when u16 { $attr.set_value($result, read-u16($b, $offset)); }
        when u8 { $attr.set_value($result, read-u8($b, $offset)); }

        when i64 { $attr.set_value($result, read-i64($b, $offset)); }
        when i32 { $attr.set_value($result, read-i32($b, $offset)); }
        when i16 { $attr.set_value($result, read-i16($b, $offset)); }
        when i8 { $attr.set_value($result, read-i8($b, $offset)); }

        when f64 { $attr.set_value($result, read-f64($b, $offset)); }
        when f32 { $attr.set_value($result, read-f32($b, $offset)); }

        # when Int { $attr.set_value($result, read-Int($b, $offset)); }
        when Str { $attr.set_value($result, read-Str($b, $offset)); }

        # when Array | array {
        when Positional {
            my $array_of = $attr.type.of;
            $attr.set_value($result, read-array($b, $array_of, $offset));
        }

        when Serializable { $attr.set_value($result, read-type($b, $_, $offset)); }

        default { die X::AdHoc.new(payload => 'read-type: unsupported type: ' ~ $_.^name); }
        } # given
    }

    $result
}

sub read-array(buf8 $b, Any:U $ty, u64 $offset is rw) is export(:read-array, :functions) {
    my @result;

    my $elems = read-u32($b, $offset);
    given $ty {

    when u64 { for 1 .. $elems { @result.push: read-u64($b, $offset); } }
    when u32 { for 1 .. $elems { @result.push: read-u32($b, $offset); } }
    when u16 { for 1 .. $elems  { @result.push: read-u16($b, $offset); } }
    when u8 { for 1 .. $elems  { @result.push: read-u8($b, $offset); } }

    when i64 { for 1 .. $elems { @result.push: read-i64($b, $offset); } }
    when i32 { for 1 .. $elems { @result.push: read-i32($b, $offset); } }
    when i16 { for 1 .. $elems { @result.push: read-i16($b, $offset); } }
    when i8 { for 1 .. $elems { @result.push: read-i8($b, $offset); } }

    when i64 { for 1 .. $elems { @result.push: read-f64($b, $offset); } }
    when i32 { for 1 .. $elems { @result.push: read-f32($b, $offset); } }

    # when Int { for 1 .. $elems { @result.push: read-Int($b, $offset); } }
    when Str { for 1 .. $elems { @result.push: read-Str($b, $offset); } }

    when Serializable { for 1 .. $elems { @result.push: read-type($b, $ty, $offset); } }

    default { die X::AdHoc.new(payload => 'read-array: unsupported type: ' ~ $ty.^name); }
    } # given

    @result
}

sub write-u64(buf8 $b, u64 $x) is export(:write-u64, :functions) {
    $b.push: ($x +& 0xFF_00_00_00_00_00_00_00) +> 0d56;
    $b.push: ($x +& 0x00_FF_00_00_00_00_00_00) +> 0d48;
    $b.push: ($x +& 0x00_00_FF_00_00_00_00_00) +> 0d40;
    $b.push: ($x +& 0x00_00_00_FF_00_00_00_00) +> 0d32;
    $b.push: ($x +& 0x00_00_00_00_FF_00_00_00) +> 0d24;
    $b.push: ($x +& 0x00_00_00_00_00_FF_00_00) +> 0d16;
    $b.push: ($x +& 0x00_00_00_00_00_00_FF_00) +> 0d08;
    $b.push: ($x +& 0x00_00_00_00_00_00_00_FF) +> 0d00;
}
sub write-u32(buf8 $b, u32 $x) is export(:write-u32, :functions) {
    $b.push: ($x +& 0xFF_00_00_00) +> 0d24;
    $b.push: ($x +& 0x00_FF_00_00) +> 0d16;
    $b.push: ($x +& 0x00_00_FF_00) +> 0d08;
    $b.push: ($x +& 0x00_00_00_FF) +> 0d00;
}
sub write-u16(buf8 $b, u16 $x) is export(:write-u16, :functions) {
    $b.push: ($x +& 0xFF_00) +> 0d08;
    $b.push: ($x +& 0x00_FF) +> 0d00;
}
sub write-u8(buf8 $b, u8 $x) is export(:write-u8, :functions) {
    $b.push: $x;
}

sub write-i64(buf8 $b, i64 $x) is export(:write-i64, :functions) {
    write-u64($b, $x);
}
sub write-i32(buf8 $b, i32 $x) is export(:write-i32, :functions) {
    write-u32($b, $x);
}
sub write-i16(buf8 $b, i16 $x) is export(:write-i16, :functions) {
    write-u16($b, $x);
}
sub write-i8(buf8 $b, i8 $x) is export(:i8, :functions) {
    write-u8($b, $x);
}

# sub write-Int(buf8 $b, Int $x) is export(:write-Int, :functions) {
#     my u64 $y = $x +& 0xFFFF_FFFF_FFFF_FFFF;
#     write-u64($b, $y);
# }

sub write-Str(buf8 $b, Str $s) is export(:write-Str, :functions) {
    my utf8 $utf8 = $s.encode('UTF-8');
    write-u32($b, $utf8.bytes);
    $b.push($utf8);
}

sub write-f64(buf8 $b, f64 $x) is export(:write-f64, :functions) {
    write-u64($b, f64-as-u64($x));
}
sub write-f32(buf8 $b, f32 $x) is export(:write-f32, :functions) {
    write-u32($b, f32-as-u32($x));
}

sub read-u64(buf8 $b, u64 $offset is rw --> u64) is export(:read-u64, :functions) {
    my u64 $result = 0
        +| $b[$offset++] +< 0d56
        +| $b[$offset++] +< 0d48
        +| $b[$offset++] +< 0d40
        +| $b[$offset++] +< 0d32
        +| $b[$offset++] +< 0d24
        +| $b[$offset++] +< 0d16
        +| $b[$offset++] +< 0d08
        +| $b[$offset++] +< 0d00
        ;
    $result
}
sub read-u32(buf8 $b, u64 $offset is rw --> u32) is export(:read-u32, :functions) {
    my u32 $result = 0
        +| $b[$offset++] +< 0d24
        +| $b[$offset++] +< 0d16
        +| $b[$offset++] +< 0d08
        +| $b[$offset++] +< 0d00
        ;
    $result
}
sub read-u16(buf8 $b, u64 $offset is rw --> u16) is export(:read-u16, :functions) {
    my u16 $result = 0
        +| $b[$offset++] +< 0d08
        +| $b[$offset++] +< 0d00
        ;
    $result
}
sub read-u8(buf8 $b, u64 $offset is rw --> u8) is export(:read-u8, :functions) {
    my u8 $result = $b[$offset++];
    $result
}

sub read-i64(buf8 $b, u64 $offset is rw --> i64) is export(:read-i64, :functions) {
    read-u64($b, $offset)
}
sub read-i32(buf8 $b, u64 $offset is rw --> i32) is export(:read-i32, :functions) {
    read-u32($b, $offset)
}
sub read-i16(buf8 $b, u64 $offset is rw --> i16) is export(:read-i16, :functions) {
    read-u16($b, $offset)
}
sub read-i8(buf8 $b, u64 $offset is rw --> i8) is export(:read-i8, :functions) {
    read-u8($b, $offset)
}

sub read-f64(buf8 $b, u64 $offset is rw --> f64) is export(:read-f64, :functions) {
    u64-as-f64(read-u64($b, $offset))
}
sub read-f32(buf8 $b, u64 $offset is rw --> f32) is export(:read-f32, :functions) {
    u32-as-f32(read-u32($b, $offset))
}

# sub read-Int(buf8 $b, u64 $offset is rw --> Int) is export(:read-Int, :functions) {
#     my Int $result = read-u64($b, $offset);
#     $result
# }

sub read-Str(buf8 $b, u64 $offset is rw --> Str) is export(:read-Str, :functions) {
    my $byte_len = read-u32($b, $offset);
    my Str $result = $b.subbuf($offset, $byte_len).decode('UTF-8');
    $offset += $byte_len;
    $result
}

=finish
