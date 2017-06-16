TITLE
=====

Read/Write native types from/to buf8 buffers.

NAME
====

Bufy - read/write native types from/to buf8 buffers

### SYNOPSIS

#### shorthand aliases to the native types

    use Bufy :constants;

    my u64 $u64 = 0xFFFF_FFFF_FFFF_FFFF; # uint64
    my u32 $u32 = 0xFFFF_FFFF; # uint32
    my u16 $u16 = 0xFFFF; # uint16
    my u8 $u8 = 0xFF; # uint8

    my i64 $u64 = 0xFFFF_FFFF_FFFF_FFFF; # int64
    my i32 $u32 = 0xFFFF_FFFF; # int32
    my i16 $u16 = 0xFFFF; # int16
    my i8 $u8 = 0xFF; # int8

    my f64 $f64 = 1.0e0; # num64;
    my f32 $f32 = 1.0e0; # num32;

### functions

    use Bufy :functions; # all functions
    use Bufy :write-u64, :read-u64; # only specific functions

##### sub write-type(buf8 $b, Any:D $x)

    class Foo {
        has u32 $.bar = 0xFFFF_FFFF;
        has f32 $.baz = 1.0e0;
    }
    my buf8 $buf .= new;
    write-type($buf, Foo.new);
    say $buf; # Buf[uint8]:0x<ff ff ff ff 3f 80 00 00>

##### sub read-type(buf8 $b, Any:U $ty is copy, u64 $offset is rw --> Any)

    my buf8 $buf .= new(0xFF, 0xFF, 0xFF, 0xFF, 0x3F, 0x80, 0x00, 0x00);
    my u64 $offset = 0;
    my Foo $foo = read-type($buf, Foo, $offset);
    say $foo; # Foo.new(bar => -1, baz => 1e0)

##### sub write-Str(buf8 $b, Str $s)

    my buf8 $buf .= new;
    write-Str($buf, 'ABCD');
    say $buf; # Buf[uint8]:0x<00 00 00 04 41 42 43 44>

##### sub read-Str(buf8 $b, u64 $offset is rw --> Str)

    my buf8 $buf .= new(0x00, 0x00, 0x00, 0x04, 0x41, 0x42, 0x43, 0x44);
    my u64 $offset = 0;
    my Str $str = read-Str($buf, $offset);
    say $str.perl; # "ABCD"

##### sub write-array(buf8 $b, Any:U $ty, @array)

##### sub read-array(buf8 $b, Any:U $ty, u64 $offset is rw)

##### sub write-u64(buf8 $b, u64 $x)

##### sub write-u32(buf8 $b, u32 $x)

##### sub write-u16(buf8 $b, u16 $x)

##### sub write-u8(buf8 $b, u8 $x)

##### sub write-i64(buf8 $b, i64 $x)

##### sub write-i32(buf8 $b, i32 $x)

##### sub write-i16(buf8 $b, i16 $x)

##### sub write-i8(buf8 $b, i8 $x)

##### sub write-f64(buf8 $b, f64 $x)

##### sub write-f32(buf8 $b, f32 $x)

##### sub read-u64(buf8 $b, u64 $offset is rw --> u64)

##### sub read-u32(buf8 $b, u64 $offset is rw --> u32)

##### sub read-u16(buf8 $b, u64 $offset is rw --> u16)

##### sub read-u8(buf8 $b, u64 $offset is rw --> u8)

##### sub read-i64(buf8 $b, u64 $offset is rw --> i64)

##### sub read-i32(buf8 $b, u64 $offset is rw --> i32)

##### sub read-i16(buf8 $b, u64 $offset is rw --> i16)

##### sub read-i8(buf8 $b, u64 $offset is rw --> i8)

##### sub read-f64(buf8 $b, u64 $offset is rw --> f64)

##### sub read-f32(buf8 $b, u64 $offset is rw --> f32)

##### sub f64-as-u64(f64 $x --> u64)

    my u64 $u64 = f64-as-u64(1.0e0);
    say $u64.base(16); # 3FF0000000000000

##### sub u64-as-f64(u64 $x --> f64)

    say u64-as-f64(0x3FF0000000000000).perl; # 1e0

##### sub f32-as-u32(f32 $x --> u32)

    my u32 $u32 = f32-as-u32(1.0e0);
    say $u32.base(16); # 3F800000

##### sub u32-as-f32(u32 $x --> f32)

    say u32-as-f32(0x3F800000).perl; # 1e0

### no-serialize trait

    class Foo {
        has u32 $.bar = 0xFFFF_FFFF;
        has f32 $.baz is no-serialize = 1.0e0;
    }
    my buf8 $buf .= new;
    write-type($buf, Foo.new);
    say $buf; # Buf[uint8]:0x<ff ff ff ff>

### array attributes

    class Foo {
        has u8 @.bar = 0xAA, 0xBB, 0xCC, 0xDD;
    }
    my buf8 $buf .= new;
    write-type($buf, Foo.new);
    say $buf; # Buf[uint8]:0x<00 00 00 04 aa bb cc dd>

### serializable attributes

    use Bufy :constants, :write-type, :Serializable;
    class Foo is Serializable {
        has u8 $.a = 1;
    }
    class Bar {
        has Foo $.foo = Foo.new;
        has u8 $.b = 2;
    }
    my buf8 $buf .= new;
    write-type($buf, Bar.new);
    say $buf; # Buf[uint8]:0x<01 02>
