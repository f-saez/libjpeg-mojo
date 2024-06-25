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
alias J_COLOR_SPACE_JCS_UNKNOWN = 0
alias J_COLOR_SPACE_JCS_GRAYSCALE = 1
alias J_COLOR_SPACE_JCS_RGB = 2
alias J_COLOR_SPACE_JCS_YCbCr = 3
alias J_COLOR_SPACE_JCS_CMYK = 4
alias J_COLOR_SPACE_JCS_YCCK = 5
alias J_COLOR_SPACE_JCS_EXT_RGB = 6
alias J_COLOR_SPACE_JCS_EXT_RGBX = 7
alias J_COLOR_SPACE_JCS_EXT_BGR = 8
alias J_COLOR_SPACE_JCS_EXT_BGRX = 9
alias J_COLOR_SPACE_JCS_EXT_XBGR = 10
alias J_COLOR_SPACE_JCS_EXT_XRGB = 11
alias J_COLOR_SPACE_JCS_EXT_RGBA = 12
alias J_COLOR_SPACE_JCS_EXT_BGRA = 13
alias J_COLOR_SPACE_JCS_EXT_ABGR = 14
alias J_COLOR_SPACE_JCS_EXT_ARGB = 15
alias J_COLOR_SPACE_JCS_RGB565 = 16
alias J_COLOR_SPACE_DEFAULT = J_COLOR_SPACE_JCS_EXT_BGRA

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