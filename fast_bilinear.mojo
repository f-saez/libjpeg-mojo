from testing import assert_equal

@value
struct Weights(CollectionElement):
    var x  :  Int
    var x1 :  Int
    var weights  : SIMD[DType.float32,8]

fn fast_bilinear(src : DTypePointer[DType.uint8,0], src_width : UInt32, src_height : UInt32, dst : DTypePointer[DType.uint8,0], dst_width : UInt32, dst_height : UInt32):
    """
        I've called it "fast" because it is faster than the other algorithms I'm using but
        to be honest, it's a very naive implementation.
        It only works for small downsizing that doesn't invoke processing more than 4 pixels at a time.
        so, src.width/2 < width < src.width (same for the height). 
        I don't check that, so you're free to do what you want but it won't be pretty :-))
        The point of this function is simple. When you open a jpeg, you could choose to downsize it
        while decompressing by a given factor (2,4,8 or 16). It's faster than opening it at full resolution and use
        less memory.
        If you want to downsize it by 2.5, you'll have to downsize it by 2 then ... then you'll have to use this function :-)
        It works in srgb colorspace, but for this kind of small reduction, it shouldn't be a big problem. 
        It's easy to to write a linear colorspace version, but the processing time will increase, obviously.

        returns :
            DTypePointer[DType.uint8,1]
            width
            height
        .
    """  
    var stride_src = src_width * 4  # RGBx32 only

    # var stride_dst = dst_width * 4  
    var coef_x = src_width.cast[DType.float32]() / dst_width.cast[DType.float32]()
    var coef_y = src_height.cast[DType.float32]() / dst_height.cast[DType.float32]()
    var src_width1 = Int(src_width.cast[DType.int32]().value) - 1 
    var src_height1 = Int(src_height.cast[DType.int32]().value) - 1 

    # we calculate the weights for a line, so we don't have to do that for each line
    var weights_x = List[Weights](capacity=Int(dst_width.cast[DType.int32]().value))
    for x in range(dst_width):
        var xz = Float32(x) * coef_x
        var x1 = xz.__floor__().clamp(0,src_width1)  # minus one, so we can blindly use x1+1
        var weight1 = xz - x1          
        var weight = 1 - weight1
        var w = Weights(
            x=x,
            x1=x1.cast[DType.int32]().value,
            weights=SIMD[DType.float32,8](weight,weight,weight,weight,weight1,weight1,weight1,weight1),
        )
        weights_x.append(w)

    var adr_dst = 0
    for y in range(dst_height):
        var yz = Float32(y) * coef_y
        var y0 = yz.__floor__().clamp(0, src_height1) 
        var weight_y1 = SIMD[DType.float32,8](yz - y0)
        var weight_y = 1 - weight_y1
        var y1 = Int(y0.cast[DType.int32]().value) * stride_src    
      
        for w in weights_x:
            var adr = w[].x1*4 + y1
            var rgba1 = src.load[width=8, alignment=4](adr).cast[DType.float32]() * w[].weights    
            # y1 + 1
            var rgba2 = src.load[width=8, alignment=4](adr+stride_src).cast[DType.float32]() * w[].weights
            var rgba = (rgba1 * weight_y + rgba2 * weight_y1).reduce_add[4]().clamp(0,255).cast[DType.uint8]()
            dst.store[width=4](adr_dst, rgba)
            adr_dst += 4


fn bilinear_dimensions(src_w : UInt32, src_h : UInt32, dst_w : UInt32, dst_h : UInt32) -> (Int, Int):
    """
        Given :
            src_w and src_h : width and height of a source image
            dst_w and dst_h : width and height of a destination image
        Knowing that we need to keep the aspect ratio, we could specify only the dst_w and dst_h will be calculated 
        or specify only the dst_h and dst_w will be calculated
        I do not want to upscale, so dst_w and dst_h will never be bigger than src_w and src_h
        last point : I need to have the size aligned on 256 bits, so dst_w and dst_h will be adapted to respect that.
    """
    var src_width = src_w.cast[DType.float32]()
    var src_height = src_h.cast[DType.float32]()
    var src_ratio = src_width / src_height
    var dst_width = dst_w.cast[DType.float32]()  
    var dst_height = dst_h.cast[DType.float32]()
    if dst_width>src_width:
        dst_width = src_width
    if dst_height>src_height:
        dst_height = src_height    
    if dst_width==0 and dst_height>0:
        dst_width = (dst_height * src_ratio).roundeven()
    elif dst_height==0 and dst_width>0:
        dst_height = (dst_width / src_ratio).roundeven()
    elif dst_height==0 and dst_width==0:         
        dst_width = src_width
        dst_height = src_height    

    # small optimisation that will remove a lots of headaches later
    # I choose to align the width of the image on 256 bits (AVX/AVX2/AVX10)
    # 4 channels => 4*UInt8 <=> 32 bits/pixel and 8 pixels => 32*8 <=> 256 bits   
    var width = (dst_width.roundeven()/8).roundeven()*8
    var height = ( width / src_ratio).roundeven()
    return ( Int(width.cast[DType.int32]().value), Int(height.cast[DType.int32]().value) )

fn validation() raises :
    validation_bilinear_dimensions()

fn validation_bilinear_dimensions() raises :
    var res = bilinear_dimensions(320, 200, 256, 212)
    assert_equal(res[0],256,"bug")
    assert_equal(res[1],160,"bug")
    res = bilinear_dimensions(320, 200, 356, 212)
    assert_equal(res[0],320,"bug")
    assert_equal(res[1],200,"bug")
    res = bilinear_dimensions(320, 200, 256, 0)
    assert_equal(res[0],256,"bug")
    assert_equal(res[1],160,"bug")
    res = bilinear_dimensions(320, 200, 0, 212)
    assert_equal(res[0],320,"bug")
    assert_equal(res[1],200,"bug")
    res = bilinear_dimensions(320, 200, 0, 0)
    assert_equal(res[0],320,"bug")
    assert_equal(res[1],200,"bug")
    res = bilinear_dimensions(320, 200, 0, 160)
    assert_equal(res[0],256,"bug")
    assert_equal(res[1],160,"bug")
    res = bilinear_dimensions(320, 200, 256, 160)
    assert_equal(res[0],256,"bug")
    assert_equal(res[1],160,"bug")
    res = bilinear_dimensions(320, 200, 256, 156)
    assert_equal(res[0],256,"bug")
    assert_equal(res[1],160,"bug")
    res = bilinear_dimensions(320, 200, 255, 156)
    assert_equal(res[0],256,"bug")
    assert_equal(res[1],160,"bug")
    res = bilinear_dimensions(320, 200, 257, 156)
    assert_equal(res[0],256,"bug")
    assert_equal(res[1],160,"bug")
    res = bilinear_dimensions(319, 200, 320, 189)
    assert_equal(res[0],320,"bug")
    assert_equal(res[1],201,"bug")        