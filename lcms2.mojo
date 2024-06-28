import sys.ffi
from pathlib import Path
from collections import Optional
from testing import assert_equal, assert_true

alias LIBLCMS2_NAME = "liblcms2.so"

alias cmsCreateContext = fn(UnsafePointer[UInt8], UnsafePointer[UInt8]) -> UnsafePointer[UInt8]
alias cmsDeleteContext = fn(UnsafePointer[UInt8]) -> Bool  # void in real life
alias cmsOpenProfileFromMemTHR = fn(UnsafePointer[UInt8], UnsafePointer[UInt8], UInt32) -> UnsafePointer[UInt8]  
alias cmsGetProfileInfoASCII = fn(UnsafePointer[UInt8], UInt32, UnsafePointer[Int8], UnsafePointer[Int8], UnsafePointer[UInt8], UInt32) -> UInt32
alias cmsCreateTransformTHR = fn(UnsafePointer[UInt8], UnsafePointer[UInt8], UInt32, UnsafePointer[UInt8], UInt32, UInt32, UInt32) -> UnsafePointer[UInt8]
alias cmsDoTransform = fn(UnsafePointer[UInt8], DTypePointer[DType.uint8, AddressSpace.GENERIC], DTypePointer[DType.uint8, AddressSpace.GENERIC], UInt32) -> Bool  # void in real life
alias cmsDeleteTransform = fn(UnsafePointer[UInt8]) -> Bool  # void in real life

alias LIBLCMS2_FLAGS_BLACKPOINTCOMPENSATION:UInt32 =   0x2000
alias LIBLCMS2_FLAGS_HIGHRESPRECALC:UInt32 = 0x0400  # Use more memory to give better accurancy
alias LIBLCMS2_FLAGS_NOCACHE:UInt32 = 0x0040  # Inhibit 1-pixel cache

alias MIN_ICC_BYTES_SIZE = 512  # I cannot think of an correct ICC profile smaller than that. Even the basic sRGBv4 is 748 bytes

# LCMS2 manage a very big number of formats, near 160. Most of them are not so common 
# or outside my needs for now.
# I'll focus on the most common and the most usefull to me for the time being
# I could have used a bunch of aliases but it'll opened a door to some failures
# with wrong values used by mistake.
# So I take a safer road. It's time-consuming to write but at least, you can only use what you are allowed to
# I really don't see myself writing 157 static functions :-))
@value
struct LibLCMS2PixelFormat:
    var value : UInt32
    var bpp : Int

    @staticmethod
    fn gray8() -> Self:
        return Self(196617, 1)

    @staticmethod
    fn gray16() -> Self:
        return Self(196618,2)

    @staticmethod
    fn rgb8() -> Self:
        return Self(262169,3)

    @staticmethod
    fn bgr8() -> Self:
        return Self(267289,3)

    @staticmethod
    fn rgba8() -> Self:
        return Self(262297,4)

    @staticmethod
    fn bgra8() -> Self:
        return Self(279705,4)

    @staticmethod
    fn argb8() -> Self:
        return Self(278681,4)

    @staticmethod
    fn abgr8() -> Self:
        return Self(263321,4)

# dear Santa Claus, I've been a really nice boy. Please bring me real enums for christmas
@value
struct LibLCMS2Intent:
    var _value : UInt32

    fn __init__(inout self):
        self._value = 0  # perceptual but default

    # first, the ICC Intent
    @staticmethod
    fn perceptual() -> Self:
        return Self(0)    

    @staticmethod
    fn relative_colorimetric() -> Self:
        return Self(1)    

    @staticmethod
    fn saturation() -> Self:
        return Self(2)    

    @staticmethod
    fn absolute_colorimetric() -> Self:
        return Self(3)    

    # then, the non-ICC Intent
    @staticmethod
    fn preserve_K_only_perceptual() -> Self:
        return Self(10)     

    @staticmethod
    fn preserve_K_only_relative_colorimetric() -> Self:
        return Self(11)     

    @staticmethod
    fn preserve_K_only_saturation() -> Self:
        return Self(12)     

    @staticmethod
    fn preserve_K_plane_perceptual() -> Self:
        return Self(13)     

    @staticmethod
    fn preserve_K_plane_relative_colorimetric() -> Self:
        return Self(14)     

    @staticmethod
    fn preserve_K_plane_saturation() -> Self:
        return Self(15)     


@value
struct LibLCMS2InfoType:
    var _value : UInt32

    @staticmethod
    fn description() -> Self:
        return Self(0) 

    @staticmethod
    fn manufacturer() -> Self:
        return Self(1) 

    @staticmethod
    fn model() -> Self:
        return Self(2) 

    @staticmethod
    fn copyright() -> Self:
        return Self(3) 


@value
struct LCMS2Context:
    var _handle          : UnsafePointer[UInt8]
    var _liblcms2_handle : ffi.DLHandle
    var __destroyed      : Bool  # Until I understand why the detructor is called two times

    fn __init__(inout self, handle : UnsafePointer[UInt8], liblcms2_handle : ffi.DLHandle):
        self._handle = handle
        self._liblcms2_handle = liblcms2_handle
        self.__destroyed = False

    @staticmethod
    fn new() -> Optional[Self]:
        """
            the "real" constructor. Why not use __init__ ?
            because __init__ always return something, so it implies a lot of tests internally to test if this value
            if ok or not.
            With this, I could return an optional, meaning if it contains something, it is always a correct value
            so no more tests.
        """
        var result = Optional[Self](None)
        var liblcms2_handle = ffi.DLHandle(LIBLCMS2_NAME, ffi.RTLD.NOW)   
        if liblcms2_handle.__bool__():
            var handle = liblcms2_handle.get_function[cmsCreateContext]("cmsCreateContext")(UnsafePointer[UInt8](), UnsafePointer[UInt8]())
            result = Optional[Self](LCMS2Context(handle, liblcms2_handle))
        return result

    # I've got big trouble if I put this code inside the destructor. I need to understand why the destructor is called mutiples times
    # https://github.com/modularml/mojo/issues/3131
    fn close(inout self):
        if not self.__destroyed:
            _ =  self.get_liblcms2_handle().get_function[cmsDeleteContext]("cmsDeleteContext")(self._handle)
            self._liblcms2_handle.close()
            self.__destroyed = True

    @always_inline
    fn get_liblcms2_handle(self) -> ffi.DLHandle:
        return self._liblcms2_handle


@value
struct LCMS2ICCProfile:
    var _hprofile :  UnsafePointer[UInt8]
    var bytes     :  List[SIMD[DType.uint8,1]]

    @staticmethod
    fn new(ctx : LCMS2Context, owned icc_profile : List[SIMD[DType.uint8,1]]) -> Optional[LCMS2ICCProfile]:
        """
            why do we need to keep icc_profile ? short answer : lifetime
            long answer : LCMS2 use only a pointer on icc_profile's bytes, so as soon as you don't need icc_profile
            mojo will remove it from memory and you may (will) run into some troubles because LCMS2 will use memory
            that does not contains a valid ICC profile anymore. It may not happen because nothing will reuse this chunks 
            of memory or it will happen after some times, or some days and not others, ...
            Call that a stealthy bug and it may drive you crazy trying to hunt it.
            So, to avoid that, and to avoid complex lifetime management, I take the ownership of icc_profile so it will
            live as long as our object.
        """
        var result = Optional[LCMS2ICCProfile](None)
        if icc_profile.size>MIN_ICC_BYTES_SIZE: 
            var liblcms2_handle = ctx.get_liblcms2_handle()
            var ptr = icc_profile.unsafe_ptr()
            var size = UInt32(icc_profile.size)
            var hprofile = liblcms2_handle.get_function[cmsOpenProfileFromMemTHR]("cmsOpenProfileFromMemTHR")(ctx._handle, ptr, size)
            result = Optional[LCMS2ICCProfile]( LCMS2ICCProfile(_hprofile=hprofile, bytes=icc_profile^) )
        return result
           

    @staticmethod
    fn from_path(ctx : LCMS2Context, filename : Path) raises -> Optional[LCMS2ICCProfile]:
        """
            Create a LCMS2ICCprofile from a icc file.
            Seems basic stuff but something smells bad because I think LCMS2 does not 
            copy the data and, obviously, this function drop the data so the profile may be rotten
            TODO : looks at the C code to check what really happens here.
        """        
        var result = Optional[LCMS2ICCProfile](None)
        if filename.is_file():
            var bytes = List[SIMD[DType.uint8,1]](capacity=filename.stat().st_size)
            with open(filename, "rb") as f:
                bytes = f.read_bytes()   
            
            if bytes.size>MIN_ICC_BYTES_SIZE:
                result = Self.new(ctx, bytes^)
        return result

    fn get_info(self, ctx : LCMS2Context, info_type : LibLCMS2InfoType) -> String:
        """
            return some data on the profile. Nothing fancy, mostly administrative stuff.
        """
        var result = String()

        var handle_liblcms2 = ctx.get_liblcms2_handle()
        var hprofile = self._hprofile
        var language_code = String("en")  # we need a zero-terminal string, so it's fine        
        var country_code = String("US")
        # first shot : I need to get the size of the string that LCMS2 will send me
        var nbytes = handle_liblcms2.get_function[cmsGetProfileInfoASCII]("cmsGetProfileInfoASCII")(hprofile, info_type._value, language_code.unsafe_ptr(), country_code.unsafe_ptr(), UnsafePointer[UInt8](), 0)
        if nbytes>0:
            # now we got the size, let's do it again and get some data
            var num_bytes = nbytes.cast[DType.int32]().value
            var bytes = List[UInt8](capacity=num_bytes)
            bytes.resize(num_bytes, 0)
            _ = handle_liblcms2.get_function[cmsGetProfileInfoASCII]("cmsGetProfileInfoASCII")(hprofile, info_type._value, language_code.unsafe_ptr(), country_code.unsafe_ptr(), bytes.unsafe_ptr(), nbytes)
            result = String(bytes)

        return result


# I should find a way to integrate in the executable a standard sRGB profile so
# we don't have to keep this file roaming in every repo
fn transform_in_place_rgb32( icc_profile_in : LCMS2ICCProfile, 
                             icc_profile_out : LCMS2ICCProfile, 
                             pixels: DTypePointer[DType.uint8, AddressSpace.GENERIC], 
                             num_pixels : Int,
                             pixel_format : LibLCMS2PixelFormat) -> Bool:
    
    var result = LCMS2Context.new()
    if result:
        var ctx = result.value()[]
        result = transform_in_place_rgb32_context(ctx, icc_profile_in, icc_profile_out, pixels, num_pixels, pixel_format)
    return result

fn transform_in_place_rgb32_context(ctx: LCMS2Context, 
                             icc_profile_in : LCMS2ICCProfile, 
                             icc_profile_out : LCMS2ICCProfile, 
                             pixels: DTypePointer[DType.uint8, AddressSpace.GENERIC], 
                             num_pixels : Int,
                             pixel_format : LibLCMS2PixelFormat) -> Bool:
    var result = False                                 

    # FLAGS_NOCACHE to make sure there is not shenanigans here between threads
    # but even in a mono-thread environnement, FLAGS_NOCACHE make next to no difference. (experienced with Rust)
    # by the way, I don't know how to create threads in Mojo so ... :-))
    var flags = LIBLCMS2_FLAGS_BLACKPOINTCOMPENSATION + LIBLCMS2_FLAGS_HIGHRESPRECALC + LIBLCMS2_FLAGS_NOCACHE
    var intent = LibLCMS2Intent.perceptual()._value
    var handle_liblcms2 = ctx.get_liblcms2_handle()
    var hprofile_in = icc_profile_in._hprofile
    var hprofile_out = icc_profile_out._hprofile
    var pixfmt = pixel_format.value
    var transform = handle_liblcms2.get_function[cmsCreateTransformTHR]("cmsCreateTransformTHR")(ctx._handle, hprofile_in, pixfmt, hprofile_out, pixfmt, intent, flags)
    if transform!=UnsafePointer[SIMD[DType.uint8,1]](): # is it a good way to detect a null pointer ?
        _ = handle_liblcms2.get_function[cmsDoTransform]("cmsDoTransform")(transform, pixels, pixels, UInt32(num_pixels) )
        _ = handle_liblcms2.get_function[cmsDeleteTransform]("cmsDeleteTransform")(transform)
        result = True

    return result

fn validation_lcms2() raises:
    var aa = LCMS2Context.new()
    assert_true(aa)
    var ctx = aa.value()[]
    var profile1 = LCMS2ICCProfile.from_path(ctx, Path("icc_profiles/RTv4_sRGB.icc"))
    assert_true(profile1)
    var profile_srgb = profile1.value()[]
    assert_equal(profile_srgb.get_info(ctx, LibLCMS2InfoType.description()), String("RTv4_sRGB"))
    assert_equal(profile_srgb.get_info(ctx, LibLCMS2InfoType.manufacturer()), String("RawTherapee"))
    assert_equal(profile_srgb.get_info(ctx, LibLCMS2InfoType.model()), String(""))
    assert_equal(profile_srgb.get_info(ctx, LibLCMS2InfoType.copyright()), String("Copyright RawTherapee 2018, CC0"))

    # DCI-P3 is a little to close to sRGB, visually it's sRGB with a better stauration
    var profile2 = LCMS2ICCProfile.from_path(ctx, Path("test/RTv4_Rec2020.icc"))
    assert_true(profile2)
    var profile_rec2020 = profile2.value()[]
    assert_equal(profile_rec2020.get_info(ctx, LibLCMS2InfoType.description()), String("RTv4_Rec2020"))
    assert_equal(profile_rec2020.get_info(ctx, LibLCMS2InfoType.manufacturer()), String("RawTherapee"))
    assert_equal(profile_rec2020.get_info(ctx, LibLCMS2InfoType.model()), String(""))
    assert_equal(profile_rec2020.get_info(ctx, LibLCMS2InfoType.copyright()), String("Copyright RawTherapee 2018, CC0"))

    var num_pixels = 9
    var pixels = DTypePointer[DType.uint8, AddressSpace.GENERIC]().alloc(num_pixels*4)
    
    # some pixels in RGBA/Rec2020
    var adr = 0
    pixels.store[width=4](adr, SIMD[DType.uint8,4](0,15,0,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](15,0,0,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](0,0,15,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](225,225,0,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](225,15,0,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](0,15,225,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](15,25,255,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](0,0,0,255))
    adr += 4
    pixels.store[width=4](adr, SIMD[DType.uint8,4](127,127,127,255))

    # let's convert them to RGBA/sRGB
    # beware, Rec2020 is way wider than sRGB so we're gonna loose a bunch of things from a colorimetric point of view
    var r = transform_in_place_rgb32_context(ctx, profile_rec2020, profile_srgb, pixels, num_pixels, LibLCMS2PixelFormat.rgba8() )
    assert_true(r)
    adr = 0
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](0,16,0,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](22,0,0,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](0,0,16,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](232,226,0,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](255,0,0,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](0,0,236,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](0,7,255,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](0,0,0,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](127,127,127,255))
    adr += 4

    # and then, back to RGBA/Rec2020. After what we had loose, it's not gonna be pretty (always from a colorimetric point of view)
    r = transform_in_place_rgb32_context(ctx, profile_srgb, profile_rec2020, pixels, num_pixels, LibLCMS2PixelFormat.rgba8() )
    assert_true(r)
    adr = 0
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](6,15,1,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](16,2,0,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](1,0,15,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](225,225,80,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](208,74,35,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](54,25,225,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](59,30,243,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](0,0,0,255))
    adr += 4
    assert_equal(pixels.load[width=4](adr), SIMD[DType.uint8,4](127,127,127,255))
    adr += 4

    ctx.close()
    pixels.free()    


