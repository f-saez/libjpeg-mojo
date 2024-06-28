alias size_t = Int

alias libc_free = fn(UnsafePointer[UInt8, AddressSpace.GENERIC]) -> Bool

alias JPEG_RST0 = 0xD0  # RST0 marker code
alias JPEG_EOI  = 0xD9  # EOI marker code 
alias JPEG_APP0 = 0xE0  # APP0 marker code
alias JPEG_COM  = 0xFE  # COM marker code

alias C_Bool = UInt32
alias C_Bool_False = 0
alias C_Bool_True = 1

alias JDIMENSION = UInt32
alias JSAMPLE = UInt8
alias JPEG_LIB_VERSION: Int32 = 62

alias J_COLOR_SPACE = UInt32

# "an enum ! an enum ! my kingdom for an enum !"
# it works but is higly inefficient
@value
struct JpegColorSpace:
    var __value : J_COLOR_SPACE
    var __bpp : Int  #  bytes per pixels

    fn __init__(inout self, value : J_COLOR_SPACE, bpp : Int):
        self.__value = value
        self.__bpp = bpp
        
    @staticmethod
    fn grayscale() -> Self:
        return Self(1,1)

    @staticmethod
    fn rgb() -> Self:
        return Self(6,3)

    @staticmethod
    fn rgbx() -> Self:
        return Self(7,4)

    @staticmethod
    fn rbgr() -> Self:
        return Self(8,4)

    @staticmethod
    fn bgrx() -> Self:
        return Self(9,4)

    @staticmethod
    fn rgba() -> Self:
        return Self(12,4)

    @staticmethod
    fn bgra() -> Self:
        return Self(13,4)

    @staticmethod
    fn abgr() -> Self:
        return Self(14,4)

    @staticmethod
    fn argb() -> Self:
        return Self(15,4)

    @staticmethod
    fn default() -> Self:
        return Self.bgra()

    @always_inline
    fn value(self) -> J_COLOR_SPACE:
        return self.__value
    
    @always_inline
    fn bpp(self) -> Int:
        return self.__bpp

alias J_DCT_METHOD = UInt32
alias J_DCT_METHOD_JDCT_ISLOW = 0
alias J_DCT_METHOD_JDCT_IFAST = 1
alias J_DCT_METHOD_JDCT_FLOAT = 2

alias J_DITHER_MODE = UInt32
alias J_DITHER_MODE_JDITHER_NONE = 0
alias J_DITHER_MODE_JDITHER_ORDERED = 1
alias J_DITHER_MODE_JDITHER_FS = 2

@value
struct JpegErrorMgr:
    var error_exit: UnsafePointer[UInt8]
    var emit_message: UnsafePointer[UInt8]
    var output_message: UnsafePointer[UInt8]
    var format_message: UnsafePointer[UInt8]
    var reset_error_mgr: UnsafePointer[UInt8]
    var msg_code: Int32
    var msg_parm: InlineArray[UInt8, 80]
    var trace_level: Int32
    var num_warnings: Int32  # or Int64 ?
    var jpeg_message_table: UnsafePointer[UnsafePointer[UInt8]]
    var last_jpeg_message: Int32
    var addon_message_table: UnsafePointer[UInt8]
    var first_addon_message: Int32
    var last_addon_message: Int32

    fn __init__(inout self):
        self.error_exit = UnsafePointer[UInt8]()
        self.emit_message = UnsafePointer[UInt8]()
        self.output_message = UnsafePointer[UInt8]()
        self.format_message = UnsafePointer[UInt8]()
        self.reset_error_mgr = UnsafePointer[UInt8]()
        self.msg_code = 0
        self.msg_parm = InlineArray[UInt8, 80](0)
        self.trace_level = 0
        self.num_warnings = 0
        self.jpeg_message_table = UnsafePointer[UnsafePointer[UInt8]]()
        self.last_jpeg_message = 0
        self.addon_message_table = UnsafePointer[UInt8]()
        self.first_addon_message = 0
        self.last_addon_message = 0  