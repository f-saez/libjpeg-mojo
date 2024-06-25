from common import *

alias jpeg_std_error = fn(UnsafePointer[JpegErrorMgr]) -> UnsafePointer[UInt8]
# doesn't return anything (void) but I haven't found yet how to do that.
# So basically everything that return a Bool should return nothing 
alias jpeg_create_decompress = fn(UnsafePointer[JpegDecompressStruct], Int32, size_t) -> Bool 
# should be an UInt64 but this type doesn't exist yet, so I guess an Int64 will do. Not that I have a choice, though
alias jpeg_mem_src = fn(UnsafePointer[JpegDecompressStruct],UnsafePointer[UInt8], Int64) -> Bool 
alias jpeg_save_markers = fn(UnsafePointer[JpegDecompressStruct], Int32, UInt32) -> Bool
alias jpeg_read_header = fn(UnsafePointer[JpegDecompressStruct], C_Bool) -> Int32
alias jpeg_calc_output_dimensions = fn(UnsafePointer[JpegDecompressStruct]) -> Bool
alias jpeg_read_icc_profile = fn(UnsafePointer[JpegDecompressStruct], UnsafePointer[UnsafePointer[UInt8]], UnsafePointer[UInt32]) -> Bool # really return a bool, this time
alias jpeg_start_decompress = fn(UnsafePointer[JpegDecompressStruct]) -> Bool 
alias jpeg_read_scanlines = fn(UnsafePointer[JpegDecompressStruct], UnsafePointer[DTypePointer[DType.uint8, AddressSpace.GENERIC]], UInt32) -> JDIMENSION
alias jpeg_finish_decompress = fn(UnsafePointer[JpegDecompressStruct]) -> Bool 
alias jpeg_destroy_decompress = fn(UnsafePointer[JpegDecompressStruct]) -> Bool 

@value
struct JpegSourceMgr:
    var next_input_byte: UnsafePointer[UInt8]
    var bytes_in_buffer: UInt64
    # everything below is not correct but as long as we don't use them in Mojo, it will work
    var init_source: UnsafePointer[UInt8]  
    var fill_input_buffer: UnsafePointer[UInt8]  
    var skip_input_data: UnsafePointer[UInt8]  
    var resync_to_restart: UnsafePointer[UInt8]  
    var term_source: UnsafePointer[UInt8]  
    
@value
struct JpegDecompressStruct:
    var err: UnsafePointer[UInt8]  # they need to exist but we won't use them, so ...
    var mem: UnsafePointer[UInt8]
    var progress:UnsafePointer[UInt8]
    var client_data: UnsafePointer[UInt8] # should be *void
    var is_decompressor: Int32
    var global_state: Int32
    var src: UnsafePointer[JpegSourceMgr] 
    var image_width: JDIMENSION
    var image_height: JDIMENSION
    var num_components: Int32
    var jpeg_color_space: J_COLOR_SPACE
    var out_color_space: J_COLOR_SPACE
    var scale_num: UInt32
    var scale_denom: UInt32
    var output_gamma: Float64
    var buffered_image: C_Bool
    var raw_data_out: C_Bool
    var dct_method: J_DCT_METHOD
    var do_fancy_upsampling: C_Bool
    var do_block_smoothing: C_Bool
    var quantize_colors: C_Bool
    var dither_mode: J_DITHER_MODE
    var two_pass_quantize: C_Bool
    var desired_number_of_colors: Int32
    var enable_1pass_quant: C_Bool
    var enable_external_quant: C_Bool
    var enable_2pass_quant: C_Bool
    var output_width: JDIMENSION
    var output_height: JDIMENSION
    var out_color_components: Int32
    var output_components: Int32
    var rec_outbuf_height: Int32
    var actual_number_of_colors: Int32
    var colormap: UnsafePointer[UInt8]
    var output_scanline: JDIMENSION
    var input_scan_number: Int32
    var input_iMCU_row: JDIMENSION
    var output_scan_number: Int32
    var output_iMCU_row: JDIMENSION
    var coef_bits: UnsafePointer[Int32]
    var quant_tbl_ptrs: InlineArray[Int, 4]    # will be filled with correct values by libjpeg, not by us
    var dc_huff_tbl_ptrs: InlineArray[Int, 4]  # will be filled with correct values by libjpeg, not by us
    var ac_huff_tbl_ptrs: InlineArray[Int, 4]  # will be filled with correct values by libjpeg, not by us
    var data_precision: Int32
    var comp_info: UnsafePointer[UInt8]
    var progressive_mode: C_Bool
    var arith_code: C_Bool
    var arith_dc_L: InlineArray[UInt8, 16]  # will be filled with correct values by libjpeg, not by us
    var arith_dc_U: InlineArray[UInt8, 16]
    var arith_ac_K: InlineArray[UInt8, 16]
    var restart_interval: UInt32
    var saw_JFIF_marker: C_Bool
    var JFIF_major_version: UInt8
    var JFIF_minor_version: UInt8
    var density_unit: UInt8
    var X_density: UInt16
    var Y_density: UInt16
    var saw_Adobe_marker: C_Bool
    var Adobe_transform: UInt8
    var CCIR601_sampling: C_Bool
    var marker_list: UnsafePointer[UInt8]
    var max_h_samp_factor: Int32
    var max_v_samp_factor: Int32
    var min_DCT_scaled_size: Int32
    var total_iMCU_rows: UInt32
    var sample_range_limit: UnsafePointer[JSAMPLE]
    var comps_in_scan: Int32
    var cur_comp_info: InlineArray[Int, 4]
    var MCUs_per_row: UInt32
    var MCU_rows_in_scan: UInt32
    var blocks_in_MCU: Int32
    var MCU_membership: InlineArray[Int32, 10]
    var Ss: Int32
    var Se: Int32
    var Ah: Int32
    var Al: Int32
    var unread_marker: Int32
    var master: UnsafePointer[UInt8]
    var main: UnsafePointer[UInt8]
    var coef: UnsafePointer[UInt8]
    var post: UnsafePointer[UInt8]
    var inputctl: UnsafePointer[UInt8]
    var marker: UnsafePointer[UInt8]
    var entropy: UnsafePointer[UInt8]
    var idct: UnsafePointer[UInt8]
    var upsample: UnsafePointer[UInt8]
    var cconvert: UnsafePointer[UInt8]
    var cquantize: UnsafePointer[UInt8]
    
    # I should just do a memeset_zero for the struct but I don't know how to do it
    fn __init__(inout self):        
        self.err = UnsafePointer[UInt8]()  # they need to exist but we won't really use them, so ...
        self.mem = UnsafePointer[UInt8]()
        self.progress = UnsafePointer[UInt8]()
        self.client_data = UnsafePointer[UInt8]() # should be *void
        self.is_decompressor = C_Bool_False
        self.global_state = 0
        self.src = UnsafePointer[JpegSourceMgr]() # should be jpeg_source_mgr
        self.image_width = 0
        self.image_height = 0
        self.num_components = 0
        self.jpeg_color_space = J_COLOR_SPACE_DEFAULT
        self.out_color_space = J_COLOR_SPACE_DEFAULT
        self.scale_num = 0
        self.scale_denom = 0
        self.output_gamma = 0.
        self.buffered_image = C_Bool_False
        self.raw_data_out = C_Bool_False
        self.dct_method = J_DCT_METHOD_JDCT_ISLOW
        self.do_fancy_upsampling = C_Bool_False
        self.do_block_smoothing = C_Bool_False
        self.quantize_colors = C_Bool_False
        self.dither_mode = J_DITHER_MODE_JDITHER_FS
        self.two_pass_quantize = C_Bool_False
        self.desired_number_of_colors = 0
        self.enable_1pass_quant = C_Bool_False
        self.enable_external_quant = C_Bool_False
        self.enable_2pass_quant = C_Bool_False
        self.output_width = 0
        self.output_height = 0
        self.out_color_components = 0
        self.output_components = 0
        self.rec_outbuf_height = 0
        self.actual_number_of_colors = 0
        self.colormap = UnsafePointer[UInt8]()
        self.output_scanline = 0
        self.input_scan_number = 0
        self.input_iMCU_row = 0
        self.output_scan_number = 0
        self.output_iMCU_row = 0
        self.coef_bits = UnsafePointer[Int32]()
        self.quant_tbl_ptrs = InlineArray[Int, 4](0)    # will be filled with correct values by libjpeg, not by us
        self.dc_huff_tbl_ptrs = InlineArray[Int, 4](0)  # will be filled with correct values by libjpeg, not by us
        self.ac_huff_tbl_ptrs = InlineArray[Int, 4](0)  # will be filled with correct values by libjpeg, not by us
        self.data_precision = 0
        self.comp_info = UnsafePointer[UInt8]()
        self.progressive_mode = C_Bool_False
        self.arith_code = C_Bool_False
        self.arith_dc_L = InlineArray[UInt8, 16](0)  # will be filled with correct values by libjpeg, not by us
        self.arith_dc_U = InlineArray[UInt8, 16](0)
        self.arith_ac_K = InlineArray[UInt8, 16](0)
        self.restart_interval = 0
        self.saw_JFIF_marker = C_Bool_False
        self.JFIF_major_version = 0
        self.JFIF_minor_version = 0
        self.density_unit = 0
        self.X_density = 0
        self.Y_density = 0
        self.saw_Adobe_marker = C_Bool_False
        self.Adobe_transform = 0
        self.CCIR601_sampling = C_Bool_False
        self.marker_list = UnsafePointer[UInt8]()
        self.max_h_samp_factor = 0
        self.max_v_samp_factor = 0
        self.min_DCT_scaled_size = 0
        self.total_iMCU_rows = 0
        self.sample_range_limit = UnsafePointer[JSAMPLE]()
        self.comps_in_scan = 0
        self.cur_comp_info = InlineArray[Int, 4](0) # ugly, should be [*mut jpeg_component_info; 4usize]
        self.MCUs_per_row = 0
        self.MCU_rows_in_scan = 0
        self.blocks_in_MCU = 0
        self.MCU_membership = InlineArray[Int32, 10](0)
        self.Ss = 0
        self.Se = 0
        self.Ah = 0
        self.Al = 0
        self.unread_marker = 0
        self.master = UnsafePointer[UInt8]()
        self.main = UnsafePointer[UInt8]()
        self.coef = UnsafePointer[UInt8]()
        self.post = UnsafePointer[UInt8]()
        self.inputctl = UnsafePointer[UInt8]()
        self.marker = UnsafePointer[UInt8]()
        self.entropy = UnsafePointer[UInt8]()
        self.idct = UnsafePointer[UInt8]()
        self.upsample = UnsafePointer[UInt8]()
        self.cconvert = UnsafePointer[UInt8]()
        self.cquantize = UnsafePointer[UInt8]()        
