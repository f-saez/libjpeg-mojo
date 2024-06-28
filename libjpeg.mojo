
import sys.ffi
from collections.vector import InlinedFixedVector
from memory.unsafe_pointer import UnsafePointer
from utils import InlineArray
from memory.unsafe import DTypePointer
from memory import memset_zero, AddressSpace
from pathlib import Path
from params_dimensions import ParamsDimensions
from params_compress import ParamsCompression
import lcms2
import fast_bilinear
from helpers import set_extension
from testing import assert_equal, assert_true
import os 
from collections import Optional

from decompress import *
from compress import *

alias LIBJPEG_NAME = "libjpeg.so"
alias LIBC_NAME = "libc.so.6"
alias DEFAULT_ICC_PROFILE = "icc_profiles/RTv4_sRGB.icc"

@value
struct LibJpeg:
    var _handle      : ffi.DLHandle
    var _handle_libc : Optional[ffi.DLHandle]
    var __destroyed  : Bool

    fn __init__(inout self, handle : ffi.DLHandle, handle_libc : Optional[ffi.DLHandle]):
        self.__destroyed = False
        self._handle = handle
        self._handle_libc = handle_libc

    @staticmethod
    fn new() -> Optional[Self]:
        var result = Optional[Self](None)
        
        var handle = ffi.DLHandle(LIBJPEG_NAME, ffi.RTLD.NOW)
        if handle:            
            var handle_libc = ffi.DLHandle(LIBC_NAME, ffi.RTLD.NOW)
            if handle_libc.__bool__():
                result = Self(handle, Optional[ffi.DLHandle](handle_libc))
            else:
                print("Unable to load ",LIBC_NAME,". Some features like ICC profiles'll be unavailable")
                result = Self(handle, Optional[ffi.DLHandle](None))
        else:
            print("Unable to load ",LIBJPEG_NAME)
        return result

    # destructor are called at least two times when I use Optional so I have to close the lib by hand
    # https://github.com/modularml/mojo/issues/3131
    fn close(inout self):
        if not self.__destroyed:
            if self._handle_libc:
                self._handle_libc.value()[].close()
            self._handle.close()
            self.__destroyed = True

    fn get_file_dimensions(self, filename : String) raises -> JpegImage:
        """
        Get_file_dimensions():
            return the width and the height of a JPEG file.
             @returns:
                a JpegImage struct
            if the file is not a valid jpeg file, the width and height will be 0.
        """
        var result = JpegImage(filename)
        if not self.__destroyed:
            if Path(result.filename).is_file():
                var bytes = List[SIMD[DType.uint8,1]](capacity=32768)
                with open(result.filename, "rb") as f:
                    # Don't need all the bytes to get the dimensions, just enough bytes for the header'll be enough.
                    # Knowing the header may incorporate EXIF data and an ICC profile, it can be tricky to how exactly how much bytes
                    # this function'll need. 
                    # It seems 32768 bytes is more than enough for all the cases I've seen in 15 years
                    bytes = f.read_bytes(32768)   
                if bytes.size>0:
                    self.get_image_dimensions(bytes, result)
        return result

    fn get_image_dimensions(self, bytes : List[SIMD[DType.uint8,1]], inout jpeg : JpegImage):
        """
        Get_image_dimensions():
            get the width and the height of a bunch of bytes representing a compressed JPEG file.
            Doesnt' take care of the ICC profile yet, so it will always return a JpegImage with an empty ICC profile.

            @returns:
                a JpegDimensions struct modified
            if the bytes doesn't represent a valid jpeg file, the width and height will be 0.
            TODO : need to handle the error from LibJpeg.
        """
        jpeg.clear()
        if not self.__destroyed:
            var err = JpegErrorMgr()
            var ptr_err = UnsafePointer[JpegErrorMgr](err) 
            var cinfo = JpegDecompressStruct()
            cinfo.err = self._handle.get_function[jpeg_std_error]("jpeg_std_error")(ptr_err)
            var size = sizeof[JpegDecompressStruct]()  
            var ptr_cinfo = UnsafePointer[JpegDecompressStruct](cinfo)
            _ = self._handle.get_function[jpeg_create_decompress]("jpeg_CreateDecompress")(ptr_cinfo, JPEG_LIB_VERSION, size)
            _ = self._handle.get_function[jpeg_mem_src]("jpeg_mem_src")(ptr_cinfo, bytes.data, bytes.size)
            _ = self._handle.get_function[jpeg_save_markers]("jpeg_save_markers")(ptr_cinfo, JPEG_APP0 + 2, 0xFFFF)
            _ = self._handle.get_function[jpeg_read_header]("jpeg_read_header")(ptr_cinfo, C_Bool_True)
            cinfo.out_color_space = JpegColorSpace.default().value()  # doesn't really matter as long as it is a legal value
            _ = self._handle.get_function[jpeg_calc_output_dimensions]("jpeg_calc_output_dimensions")(ptr_cinfo)
            jpeg.set_dimensions(cinfo.image_width, cinfo.image_height, cinfo.image_width, cinfo.image_height)
            jpeg._rotated = False                      
            _ = self._handle.get_function[jpeg_destroy_decompress]("jpeg_destroy_decompress")(ptr_cinfo)

    fn from_path(self, filename : Path, dimensions : ParamsDimensions, cs : JpegColorSpace) raises -> Optional[JpegImage]:
        var result = Optional[JpegImage](None)
        if filename.is_file() and not self.__destroyed:
            var bytes = List[SIMD[DType.uint8,1]](capacity=filename.stat().st_size)
            with open(filename, "rb") as f:
                # Don't need all the bytes to get the dimensions, just enough bytes for the header'll be enough.
                # Knowing the header may incorporate EXIF data and an ICC profile, it can be tricky to how exactly how much bytes
                # this function'll need. 
                # It seems 32768 bytes is more than enough for all the cases I've seen in 15 years
                bytes = f.read_bytes()   
            if bytes.size>0:
                var img = JpegImage(filename.__str__())
                if self.decompress(bytes, dimensions, img, cs):
                    result = Optional[JpegImage](img)
        return result

    # to be complete, we'll need to add the rotation (need EXIF for that)
    # to be fair, I only work in RGBA32, wether it be RGBA, BGRA, BGRX, ... I don't wanna have to deal with something 
    # that is not 32bits/pixels or CMYK, for obvious reasons.
    # I could add Gray8
    fn decompress(self, bytes : List[SIMD[DType.uint8,1]], dimensions : ParamsDimensions, inout image : JpegImage, cs : JpegColorSpace) -> Bool:
        var result = False
        if bytes.size>256 and not self.__destroyed: # one can't really have a well formed JPEG's file of less than 256 bytes
            var err = JpegErrorMgr()
            var ptr_err = UnsafePointer[JpegErrorMgr](err) 
            var cinfo = JpegDecompressStruct()
            cinfo.err = self._handle.get_function[jpeg_std_error]("jpeg_std_error")(ptr_err)
            var size = sizeof[JpegDecompressStruct]()  
            var ptr_cinfo = UnsafePointer[JpegDecompressStruct](cinfo)
            _ = self._handle.get_function[jpeg_create_decompress]("jpeg_CreateDecompress")(ptr_cinfo, JPEG_LIB_VERSION, size)
            _ = self._handle.get_function[jpeg_mem_src]("jpeg_mem_src")(ptr_cinfo, bytes.data, bytes.size)
            _ = self._handle.get_function[jpeg_save_markers]("jpeg_save_markers")(ptr_cinfo, JPEG_APP0 + 2, 0xFFFF) # to be able to get the ICC profile
            _ = self._handle.get_function[jpeg_read_header]("jpeg_read_header")(ptr_cinfo, C_Bool_True)
            cinfo.out_color_space = cs.value()  
            _ = self._handle.get_function[jpeg_calc_output_dimensions]("jpeg_calc_output_dimensions")(ptr_cinfo)
            
            # ICC my friend, where art thou ? we only take care of the ICC profile if we could call "free"
            if self._handle_libc:                                
                var handle_libc = self._handle_libc.value()[]
                var icc_jpeg_ptr = UnsafePointer[UInt8]()  # *mut uint8 and null ptr
                var icc_jpeg_ptr2 = UnsafePointer[UnsafePointer[UInt8]](icc_jpeg_ptr)  # *mut *mut uint8
                var icc_data_len:UInt32 = 0
                var icc_data_len_ptr = UnsafePointer[UInt32](icc_data_len) 
                if self._handle.get_function[jpeg_read_icc_profile]("jpeg_read_icc_profile")(ptr_cinfo, icc_jpeg_ptr2, icc_data_len_ptr):
                    image.icc.clear()    
                    # why the copy ? because icc_jpeg_ptr has been allocated outside Mojo       
                    for idx in range(icc_data_len):                
                        image.icc.append(icc_jpeg_ptr[idx])              
                    # now we got a little problem. Libjpeg has allocated some memory for icc_jpeg_ptr but we need to deallocate it
                    # by calling free from the libc (linux) or whatever library is used with this function on other OSes
                    # Obviously, asking Mojo do de-allocate himself this memory is a recipe for disaster :-)
                    # I need link libc just for that line :-)
                    _ = handle_libc.get_function[libc_free]("free")(icc_jpeg_ptr)
                
            # original size
            var full_width = cinfo.output_width
            var full_height = cinfo.output_height
            var tmp = dimensions.get_new_dimensions( full_width, full_height)
            var width = tmp.width
            var height = tmp.height
            # I downscale, but never upscale
            var need_downscale = width!=full_width or height!=full_height
            var found = 8
            if need_downscale:
                # we need to find the closer but bigger size available 
                cinfo.scale_num = 1
                cinfo.scale_denom = 8  # see the documentation, not many choice but that'll do
                for i in range(1,cinfo.scale_denom):
                    var r = Float32(i) / cinfo.scale_denom.cast[DType.float32]()
                    if (r * cinfo.output_height.cast[DType.float32]()) >= height.cast[DType.float32]():
                        found = i
                        break                    
                if found and found< 8:  # we have found something usable
                    cinfo.scale_num = found
                else:  # nope, we stay as is
                    cinfo.scale_num = 1
                    cinfo.scale_denom = 1

            # this is a slow function !
            _ = self._handle.get_function[jpeg_start_decompress]("jpeg_start_decompress")(ptr_cinfo)

            image.set_dimensions(cinfo.output_width, cinfo.output_height, full_width, full_height)            
            var offset = 0
            var stride = Int(cinfo.output_width.cast[DType.int32]().value) * 4 
            while cinfo.output_scanline < cinfo.output_height:
                var adr = image.pixels.offset(offset)
                var jsamparray = UnsafePointer[DTypePointer[DType.uint8, AddressSpace.GENERIC]](adr)
                _ = self._handle.get_function[jpeg_read_scanlines]("jpeg_read_scanlines")(ptr_cinfo, jsamparray, 1)
                offset += stride

            _ = self._handle.get_function[jpeg_finish_decompress]("jpeg_finish_decompress")(ptr_cinfo)                        
            _ = self._handle.get_function[jpeg_destroy_decompress]("jpeg_destroy_decompress")(ptr_cinfo)
            result = True
            if need_downscale:
                if found>=2:
                    image = image.__fast_bilinear__(width, height)                    
                     
        return result


    fn compress(self, bytes : DTypePointer[DType.uint8, AddressSpace.GENERIC], width : UInt32, height : UInt32, params : ParamsCompression, icc_profile : List[SIMD[DType.uint8,1]], cs : JpegColorSpace) -> List[SIMD[DType.uint8,1]]:
        var num_bytes = Int(width.cast[DType.int32]().value) * Int(height.cast[DType.int32]().value) * cs.bpp()
        var buffer_dest =  List[SIMD[DType.uint8,1]](capacity=num_bytes)
        if width>0 and height>0 and not self.__destroyed: # rgbx32 mandatory, for now
            # to avoid any kind of memory trouble, I work with a buffer sized as a uncompressed image and will downsized it later.
            buffer_dest.resize(num_bytes,0)
            var err = JpegErrorMgr()
            var ptr_err = UnsafePointer[JpegErrorMgr](err) 
            var cinfo = JpegCompressStruct()
 
            cinfo.err = self._handle.get_function[jpeg_std_error]("jpeg_std_error")(ptr_err)
            var size = sizeof[JpegCompressStruct]()
            var ptr_cinfo = UnsafePointer[JpegCompressStruct](cinfo)
            _ = self._handle.get_function[jpeg_create_compress]("jpeg_CreateCompress")(ptr_cinfo, JPEG_LIB_VERSION, size)   

            var buffer_size = UInt64(buffer_dest.size)
            var dest_ptr = buffer_dest.unsafe_ptr()
            var dest_ptr_ptr = UnsafePointer[UnsafePointer[UInt8]](dest_ptr)
            # we use a pointer on uint64 to get the real size of buffer_dest. More at the end of the function
            # by the way, I don't like the way it works but we're working with an old codebase, so ...
            var ptr_buffersize = UnsafePointer[SIMD[DType.uint64,1]](buffer_size)
            _ = self._handle.get_function[jpeg_mem_dest]("jpeg_mem_dest")(ptr_cinfo, dest_ptr_ptr, ptr_buffersize)
            cinfo.image_width = width
            cinfo.image_height = height
            cinfo.input_components = 4
            cinfo.in_color_space = cs.value()
            cinfo.data_precision = params.data_precision # only 8 bits for now
            _ = self._handle.get_function[jpeg_set_defaults]("jpeg_set_defaults")(ptr_cinfo)

            # The accurate DCT/IDCT algorithms are now the default for both compression and decompression,
            # since the "fast" algorithms are considered to be a legacy feature. (The "fast" algorithms
            # do not pass the ISO compliance tests, and those algorithms are not any
            # faster than the accurate algorithms on modern x86 CPUs.)
            cinfo.dct_method = J_DCT_METHOD_JDCT_ISLOW
            cinfo.arith_code = params.get_arithmetic()
            # chrominance_subsampling => 4:2:0, else 4:4:4
            if params.chrominance_subsampling == False:
                cinfo.comp_info[].v_samp_factor = 1
                cinfo.comp_info[].h_samp_factor = 1
            
            cinfo.optimize_coding = C_Bool_False
            cinfo.density_unit = params.density_unit
            cinfo.X_density = params.x_density
            cinfo.Y_density = params.y_density
            
            _ = self._handle.get_function[jpeg_set_quality]("jpeg_set_quality")(ptr_cinfo, params.compression, C_Bool_True)
            _ = self._handle.get_function[jpeg_start_compress]("jpeg_start_compress")(ptr_cinfo, C_Bool_True)
            # even without libc, we can write the ICC profile
            if icc_profile.size>0:
                var ptr = icc_profile.unsafe_ptr()
                var size = Int32(icc_profile.size)
                _ = self._handle.get_function[jpeg_write_icc_profile]("jpeg_write_icc_profile")(ptr_cinfo, ptr, size )

            var index = 0
            var stride = Int(cinfo.image_width.cast[DType.int32]().value) * Int(cinfo.input_components.cast[DType.int32]().value)
            # we write the lines one by one.
            while cinfo.next_scanline < cinfo.image_height:
                var adr = bytes.offset(index)
                var jsamparray = UnsafePointer[DTypePointer[DType.uint8, AddressSpace.GENERIC]](adr)
                var n = self._handle.get_function[jpeg_write_scanlines]("jpeg_write_scanlines")(ptr_cinfo, jsamparray, 1 )
                index += stride * n.cast[DType.int32]().value

            # the correct value of buffer_size will be determined by jpeg_finish_compress
            _ = self._handle.get_function[jpeg_finish_compress]("jpeg_finish_compress")(ptr_cinfo)                     
            _ = self._handle.get_function[jpeg_destroy_compress]("jpeg_destroy_compress")(ptr_cinfo)

            # buffer_size should contains the real size of buffer_dest
            buffer_dest.resize(buffer_size.cast[DType.int64]().value,0)
        else:
            buffer_dest.clear()

        return buffer_dest

    fn to_path(self, file_name : Path, img : JpegImage, params : ParamsCompression, cs : JpegColorSpace) raises -> Bool:
        var result = False
        if not self.__destroyed:
            var filename = set_extension(file_name,"jpg")
            var bytes = self.compress(img.pixels, img.get_width(), img.get_height(), params, img.icc, cs)
            var t = bytes.size
            if t>1:
                bytes.append(bytes[t-1]) # write remove the last byte of everything, string or not, so ...
                with open(filename, "wb") as f:
                    f.write(bytes)  # expect a string but is happy to accept a bunch of bytes (why ?), except it just eat the last byte thinking it's a zero-terminal string 
                    result = True  
        else:
            print("the library is already been destroyed")
        return result


@value
struct JpegImage(Stringable):
    var filename : String
    var pixels : DTypePointer[DType.uint8, AddressSpace.GENERIC]  # the bytes describing the image
    var _num_bytes : Int
    var _width : UInt32   #  the width of the actual image
    var _height : UInt32  #  the height of the actual image
    var icc : List[SIMD[DType.uint8,1]] # the ICC profile. Using a list is a lazy solution.
    var _num_pixels : Int
    var colorspace : JpegColorSpace

    # this two fields are usefull when you open the image at a lower resolution
    # (a thumbnail) but need the real size of the image for other purpose
    var _full_width: UInt32  # the full width of the image, may differ from width if the image has been opened at a lower resolution
    var _full_height: UInt32 # the full height of the image, may differ from height if the image has been opened at a lower resolution
    var _rotated : Bool      # True if the image has been rotated but it implies access to EXIF data (for now, I can't)

    fn __init__(inout self, filename : String):
        """
        """
        self.filename = filename
        self.pixels = DTypePointer[DType.uint8, AddressSpace.GENERIC]()
        self._num_bytes = 0
        self._width = 0
        self._height = 0
        self.icc = List[SIMD[DType.uint8,1]]()
        self._full_width = 0
        self._full_height = 0
        self._rotated = False
        self._num_pixels = Int(self._width.cast[DType.int32]().value) * Int(self._height.cast[DType.int32]().value)
        self.colorspace = JpegColorSpace.default() # do not use anything else right now !

    fn set_dimensions(inout self, width : UInt32, height : UInt32, full_width : UInt32, full_height : UInt32):
        """
            set all the dimensions of the image.
            also deallocate existing pixels buffer and allocate new one with the right size.
        """
        if self._num_bytes>0:
            self.pixels.free()
        self._num_pixels = Int(width.cast[DType.int32]().value) * Int(height.cast[DType.int32]().value) # working with UInt32 is painfull   
        self._num_bytes = self._num_pixels * self.colorspace.bpp()
        self.pixels = self.pixels.alloc(self._num_bytes) # I should be smarter than that and reuse existing memory whenever it's possible
        self._width = width
        self._height = height
        self._full_width = full_width
        self._full_height = full_height

    fn __str__(self) -> String:
        return self.filename+": "+String(self._width)+"x"+String(self._height)

    fn __fast_bilinear__(self, width : UInt32, height : UInt32) -> Self:
        """
            As I adjust the size of the width to keep an alignement on 256 bits, the returned width may be a little bit different
            than the requested width. And as I try to keep the aspect ratio, the height might be also a little bit differrent.
        """
        var tmp = fast_bilinear.bilinear_dimensions(self.get_width(), self.get_height(), width, height)
        var result = Self(self.filename)
        result.set_dimensions(tmp[0], tmp[1], self.get_full_width(), self.get_full_height() )
        fast_bilinear.fast_bilinear(self.pixels, self.get_width(), self.get_height(), result.pixels, result.get_width(), result.get_height() )
        result.icc = self.icc
        return result

    fn to_ppm(self, x : Path) raises -> Bool:
        """
            Save the file as a PPM File.
            PPM is a bare-bone file format, uncompressed, RGB pixel format. (P6)
            Just here for helping the debug.
        """
        var filename = set_extension(x,"ppm")
        var w = Int(self.get_width().cast[DType.int32]().value)
        var h = Int(self.get_height().cast[DType.int32]().value)
        var num_pixels = w*h
        var header = "P6\n"+String(w)+" "+String(h)+"\n255\n"  
        var bytes = List[UInt8](capacity=w*h*3)
        
        for adr in range(num_pixels): 
            var rgba = self.pixels.load[width=4](adr*self.colorspace.bpp())
            bytes.append( rgba[2] )  # BGRA by default and PPM is RGB
            bytes.append( rgba[1] )
            bytes.append( rgba[0] )
        var t = len(bytes)
        bytes.append(bytes[t-1]) # write remove the last byte of everything, string or not, so ...
        with open(filename, "wb") as f:
            f.write(header)
            f.write(bytes)  # expect a string but is happy to accept a bunch of bytes (why ?), except it just eat the last byte thinking it's a zero-terminal string        
        return True  
    
    @staticmethod
    fn from_ppm(filename : Path) raises -> Self:
        """
            Only PPM P6 => RGB <=> 3xUInt8
            PPM could contains a comment and the comment must begin with #
            here we see a point of failure because we could use a comment starting with a digit
            and it will break the width/height detection
            a good pratice'll have been to put the mandatory fields (width/height/maxval) right after the magic byte 
            and the facultative comment at the end of the header.
            Just here for helping the debug.
        """        
        var width = 0
        var height = 0
        var idx = 0

        if filename.is_file():
            var header = List[UInt8]()
            with open(filename, "rb") as f:
                header = f.read_bytes(512)
            if header[0] == 0x50 and header[1] == 0x36:  # => P6 
                idx = 2
                for _ in range(idx, header.size):  # entering a comment area that may not exist
                    if header[idx] == 0x0A:
                        if header[idx+1]!=ord("#"):  # it's not a comment                        
                            break
                    idx += 1
                var idx_start = idx
                for _ in range(idx, header.size):  # the width
                    if header[idx] == 0x20:                        
                        idx += 1
                        width = atol( String(header[idx_start:idx]) )
                        break
                    idx += 1
                idx_start = idx
                for _ in range(idx, header.size): # the height
                    if header[idx] == 0x0A:
                        idx += 1
                        height = atol( String(header[idx_start:idx]) )
                        break
                    idx += 1
                for _ in range(idx, header.size):  # MAXVAL. I don't care because I only use Uint8 
                    if header[idx] == 0x0A:
                        idx += 1 
                        break
                    idx += 1                    

        var result = Self(filename.__str__())
        if width>0 and height>0:
            var bytes = List[UInt8](capacity=width*height*3)
            with open(filename, "rb") as f:
                bytes = f.read_bytes()            
            if bytes.size>=width*height*3:
                result.set_dimensions(width, height, width, height)
                var idx1 = 0
                for _ in range(0,bytes.size,3):
                    result.pixels[idx1]   = bytes[idx+2] # PPM is RGB and we use BGRA by default
                    result.pixels[idx1+1] = bytes[idx+1]
                    result.pixels[idx1+2] = bytes[idx]
                    result.pixels[idx1+3] = 255
                    idx1 += 4
                    idx += 3
            
        return result

    fn to_jpeg(self, filename : Path, params : ParamsCompression, libjpeg : LibJpeg, cs : JpegColorSpace) raises -> Bool:
        """ 
            save the image as a jpeg file.
        """        
        return libjpeg.to_path(filename, self, params, cs)

    @staticmethod
    fn from_jpeg(filename : Path, params : ParamsDimensions, libjpeg : LibJpeg, cs : JpegColorSpace) raises -> Optional[Self]:
        """ 
            load the image as a jpeg file.
        """        
        return libjpeg.from_path(filename, params, cs)

    fn convert_to_icc_profile(inout self, ctx : lcms2.LCMS2Context, owned profile_new : lcms2.LCMS2ICCProfile) raises -> Bool:
        var result = False
        """ 
            convert the image from one ICC profile (the one embedded in the jpeg file) to a new one.
            The unwritten rule is : if an image does not have a icc profile, then it have basic sRGB profile
            So, when one want to convert from an image without any icc profile to another icc  profile
            we need to have acces to the basic sRGB profile 
            After that, it basic stuff.            
            NB : a thing that no one should ever do is this :
                convert an image to whatever ICC profile you want then save the image WITHOUT embedding the ICC profile.
                When any software will open the image, it will think, lacking the profile, it's an sRGB image when it's not.
                If you ever have found a blueish image without knowing what is the cause, it basically an image 
                with an AdobeRGB icc profile saved without embedding the AdobeRGB profile.
        """
           
        var tmp3 = Optional[lcms2.LCMS2ICCProfile](None)
        if self.icc.size==0: # not ICC profile means sRGB
            tmp3 = lcms2.LCMS2ICCProfile.from_path(ctx, Path(DEFAULT_ICC_PROFILE))
        else:
            tmp3 = lcms2.LCMS2ICCProfile.new(ctx, self.icc)
        if tmp3:
            var profile_current = tmp3.value()[]
            var tmp4 = Optional[lcms2.LibLCMS2PixelFormat](None)
            if self.colorspace.value()==JpegColorSpace.bgra().value():
                tmp4 = Optional[lcms2.LibLCMS2PixelFormat](lcms2.LibLCMS2PixelFormat.bgra8())
            elif self.colorspace.value()==JpegColorSpace.rgba().value():
                tmp4 = Optional[lcms2.LibLCMS2PixelFormat](lcms2.LibLCMS2PixelFormat.rgba8())
            elif self.colorspace.value()==JpegColorSpace.argb().value():
                tmp4 = Optional[lcms2.LibLCMS2PixelFormat](lcms2.LibLCMS2PixelFormat.argb8())                        
            elif self.colorspace.value()==JpegColorSpace.abgr().value():
                tmp4 = Optional[lcms2.LibLCMS2PixelFormat](lcms2.LibLCMS2PixelFormat.abgr8())
            if tmp4:
                var pixel_format = tmp4.value()[]
                result = lcms2.transform_in_place_rgb32_context(ctx, profile_current, profile_new, self.pixels, self._num_pixels, pixel_format)
                if result:
                    self.icc = profile_new.bytes # keep the new profile for embedding in a future save
        return result

    fn convert_to_srgb(inout self) raises -> Bool:
        var result = False
        """ 
           
        """
        var filename = Path(DEFAULT_ICC_PROFILE)
        if filename.is_file():
            if self.icc.size==0: # already an sRGB, by default
                result = True
                self.icc.clear()
                with open(filename, "rb") as f:  # just because we are nice guys :-)
                    self.icc = f.read_bytes()
            else:
                var aa = lcms2.LCMS2Context.new()
                if aa:
                    var ctx = aa.value()[]
                    var bb = lcms2.LCMS2ICCProfile.from_path(ctx, filename)
                    if bb:
                        var profile = bb.value()[]
                        result = self.convert_to_icc_profile(ctx, profile^)
                    ctx.close()
                    
        return result

    fn clear(inout self):     
        if self._num_bytes>0:   
            self.pixels.free()  # I should be smarter than that and reuse existing memory if possible
            self._num_bytes = 0
        self._width = 0
        self._height = 0
        self._full_width = 0
        self._full_height = 0
        self._rotated = False
        self.icc.clear()

    @always_inline
    fn get_width(self) -> UInt32:
        return self._width

    @always_inline
    fn get_full_width(self) -> UInt32:
        return self._full_width

    @always_inline
    fn get_height(self) -> UInt32:
        return self._height

    @always_inline
    fn get_full_height(self) -> UInt32:
        return self._full_height

    @always_inline
    fn is_rotated(self) -> Bool:
        return self._rotated

fn validation() raises:
    ParamsDimensions.validation()
    fast_bilinear.validation()
    helpers.validation()
    validation_libjpeg()
    lcms2.validation_lcms2() 

fn validation_libjpeg() raises :
    var cs = JpegColorSpace.default()
    var aaa = LibJpeg.new()
    assert_true(aaa)
    var libjpeg = aaa.value()[]
    var img = libjpeg.get_file_dimensions("test/image.jpg")
    assert_equal(img.get_width(),314)
    assert_equal(img.get_full_width(),314)
    assert_equal(img.get_height(),471)
    assert_equal(img.get_full_height(),471)
    assert_equal(img.icc.size,0) # get_file_dimensions doesn't take care of the profile yet, so it 0

    var dim = ParamsDimensions.new_width(220)
    var bbb = libjpeg.from_path(Path("test/image_icc.jpg"), dim, cs)
    assert_true(bbb)
    img = bbb.value()[]
    assert_equal(img.get_width(),224)
    assert_equal(img.get_full_width(),314)
    assert_equal(img.get_height(),336)
    assert_equal(img.get_full_height(),471)
    assert_equal(img.icc.size,748)    
    
    var result = img.to_ppm(Path("test/image_tempo.ppm"))
    assert_true(result)
    assert_true( helpers.compare_files(Path("test/image_tempo.ppm"), Path("test/image_tempo_ref.ppm")) )
    os.path.path.remove("test/image_tempo.ppm")

    var params_compress = ParamsCompression(98,False)
    result = img.to_jpeg(Path("test/image_tempo.jpg"), params_compress, libjpeg, cs)
    assert_true(result)
    assert_true( helpers.compare_files(Path("test/image_tempo.jpg"), Path("test/image_tempo_ref.jpg")) )
    os.path.path.remove("test/image_tempo.jpg")

    var img2 = JpegImage.from_ppm("test/image_tempo_ref.ppm")
    result = img2.to_ppm(Path("test/image_tempo.ppm"))
    assert_true(result)
    assert_true( helpers.compare_files(Path("test/image_tempo.ppm"), Path("test/image_tempo_ref.ppm")) )
    os.path.path.remove("test/image_tempo.ppm")

    img = libjpeg.get_file_dimensions("test/image_Rec2020.jpg")
    assert_equal(img.get_width(),314)
    assert_equal(img.get_full_width(),314)
    assert_equal(img.get_height(),471)
    assert_equal(img.get_full_height(),471)
    assert_equal(img.icc.size,0)

    dim = ParamsDimensions.new()
    bbb = libjpeg.from_path(Path("test/image.jpg"), dim, cs)
    assert_true(bbb)
    img = bbb.value()[]
    assert_equal(img.get_width(),312)
    assert_equal(img.get_full_width(),314)
    assert_equal(img.get_height(),468)
    assert_equal(img.get_full_height(),471)
    assert_equal(img.icc.size,0)

    var aa = lcms2.LCMS2Context.new()
    assert_true(aa)
    var ctx = aa.value()[]
    var profile2 = lcms2.LCMS2ICCProfile.from_path(ctx, Path("test/DCI-P3 D65.icc"))
    assert_true(profile2)
    var profile_DCIP3 = profile2.value()[]
    var size_DCIP3 = profile_DCIP3.bytes.size
    result = img.convert_to_icc_profile(ctx, profile_DCIP3^)
    assert_true(result)

    ctx.close()

    result = img.to_jpeg(Path("test/image_tempo.jpg"), params_compress, libjpeg, cs)
    assert_true(result)
    img.clear()

    bbb = libjpeg.from_path(Path("test/image_tempo.jpg"), dim, cs)
    assert_true(bbb)
    img = bbb.value()[]
    assert_equal(img.get_width(),312)
    assert_equal(img.get_full_width(),312)
    assert_equal(img.get_height(),468)
    assert_equal(img.get_full_height(),468)
    assert_equal(img.icc.size,size_DCIP3)
    os.path.path.remove("test/image_tempo.jpg")
    img.clear()
    libjpeg.close()

fn main() raises:
    validation_libjpeg()
